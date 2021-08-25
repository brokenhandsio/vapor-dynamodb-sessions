#!/usr/bin/swift
import Foundation

let tableName = "session-tests"
let port = 8000
let containerName = "dynamodb-vapor-sessions-test"
let awsProfileName = "tests"

print("Starting local database in container \(containerName). \nTable name is \(tableName)")

@discardableResult
func shell(_ args: String..., returnStdOut: Bool = false) -> (Int32, Pipe) {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
  let pipe = Pipe()
  if returnStdOut {
      task.standardOutput = pipe
  }
  task.launch()
  task.waitUntilExit()
  return (task.terminationStatus, pipe)
}

extension Pipe {
    func string() -> String? {
        let data = self.fileHandleForReading.readDataToEndOfFile()
        let result: String?
        if let string = String(data: data, encoding: String.Encoding.utf8) {
            result = string
        } else {
            result = nil
        }
        return result
    }
}

print("Creating database... 💾")

let (dockerResult, _) = shell("docker", "run", "--name", containerName, "-p", "\(port):8000", "-d", "amazon/dynamodb-local")

guard dockerResult == 0 else {
    print("❌ ERROR: Failed to create the database")
    exit(1)
}

print("Database created in Docker 🐳")

let (createTableResult, _) = shell("aws", "dynamodb", "create-table", "--table-name", tableName, "--region", "us-east-1",
   "--attribute-definitions",
        "AttributeName=pk,AttributeType=S",
        "AttributeName=sk,AttributeType=S",
   "--key-schema", "AttributeName=pk,KeyType=HASH", "AttributeName=sk,KeyType=RANGE",
   "--billing-mode=PAY_PER_REQUEST", "--endpoint-url",  "http://localhost:\(port)", "--profile", awsProfileName, returnStdOut: true)

 guard createTableResult == 0 else {
   print("❌ ERROR: Failed to create the table")
   exit(1)
 }
