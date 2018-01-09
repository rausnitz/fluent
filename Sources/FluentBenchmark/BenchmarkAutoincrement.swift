import Async
import Service
import Dispatch
import Fluent
import Foundation

extension Benchmarker where Database: QuerySupporting {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws -> Future<Void> {
        let message = LogMessage<Database>(message: "hello")

        if message.id != nil {
            fail("message ID was incorrectly set")
        }

        let test = LogMessage<Database>(message: "test")
        return message.save(on: conn).flatMap(to: Void.self) {
            return Database.modelEvent(event: .didCreate, model: test, on: conn)
        }.map(to: Void.self) {
            if test.id != message.id {
                throw FluentBenchmarkError(
                    identifier: "model-autoincrement-mismatch",
                    reason: "The model ID was incorrectly set to \(message.id?.description ?? "nil") instead of \(test.id?.description ?? "nil")"
                )
            }
        }
    }

    /// Benchmark the Timestampable protocol
    public func benchmarkAutoincrement() throws -> Future<Void> {
        return pool.requestConnection().flatMap(to: Void.self) { conn in
            return try self._benchmark(on: conn).map(to: Void.self) {
                return self.pool.releaseConnection(conn)
            }
        }
    }
}

extension Benchmarker where Database: QuerySupporting & SchemaSupporting {
    /// Benchmark the Timestampable protocol
    /// The schema will be prepared first.
    public func benchmarkAutoincrement_withSchema() throws -> Future<Void> {
        return pool.requestConnection().flatMap(to: Database.Connection.self) { conn in
            let promise = Promise<Database.Connection>()
            
            LogMessageMigration<Database>.prepare(on: conn).do {
                promise.complete(conn)
            }.catch { _ in
                promise.complete(conn)
            }
            
            return promise.future
        }.flatMap(to: Void.self) { conn in
            return try self._benchmark(on: conn).map(to: Void.self) {
                self.pool.releaseConnection(conn)
            }
        }
    }
}