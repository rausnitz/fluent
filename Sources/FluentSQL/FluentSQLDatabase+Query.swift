extension FluentSQLDatabase {
    internal func convert(_ fluent: DatabaseQuery) -> SQLExpression {
        let sql: SQLExpression
        switch fluent.action {
        case .read: sql = self.select(fluent)
        case .create: sql = self.insert(fluent)
        case .update: sql = self.update(fluent)
        case .delete: sql = self.delete(fluent)
        case .custom(let any):
            #warning("TODO:")
            return any as! SQLExpression
        }
        return self.delegate.convert(fluent, sql)
    }
    
    // MARK: Private
    
    private func delete(_ query: DatabaseQuery) -> SQLExpression {
        var delete = SQLDelete(table: SQLIdentifier(query.entity))
        delete.predicate = self.filters(query.filters)
        return delete
    }
    
    private func update(_ query: DatabaseQuery) -> SQLExpression {
        var update = SQLUpdate(table: SQLIdentifier(query.entity))
        #warning("TODO: better indexing")
        for (i, field) in query.fields.enumerated() {
            update.values.append(SQLBinaryExpression(
                left: self.field(field),
                op: SQLBinaryOperator.equal,
                right: self.value(query.input[0][i])
            ))
        }
        update.predicate = self.filters(query.filters)
        return update
    }
    
    private func select(_ query: DatabaseQuery) -> SQLExpression {
        var select = SQLSelect()
        select.tables.append(SQLIdentifier(query.entity))
        select.columns = query.fields.map(self.field)
        select.predicate = self.filters(query.filters)
        return select
    }
    
    private func insert(_ query: DatabaseQuery) -> SQLExpression {
        var insert = SQLInsert(table: SQLIdentifier(query.entity))
        insert.columns = query.fields.map(self.field)
        insert.values = query.input.map { row in
            return row.map(self.value)
        }
        return insert
    }
    
    private func filters(_ filters: [DatabaseQuery.Filter]) -> SQLExpression? {
        guard !filters.isEmpty else {
            return nil
        }
        return SQLList(
            items: filters.map(self.filter),
            separator: SQLBinaryOperator.and
        )
    }
    
    private func field(_ field: DatabaseQuery.Field) -> SQLExpression {
        switch field {
        case .custom(let any):
            #warning("TODO:")
            return any as! SQLExpression
        case .field(let name, let entity):
            if let entity = entity {
                return SQLColumn(SQLIdentifier(name), table: SQLIdentifier(entity))
            } else {
                return SQLIdentifier(name)
            }
        }
    }
    
    private func filter(_ filter: DatabaseQuery.Filter) -> SQLExpression {
        switch filter {
        case .basic(let field, let method, let value):
            return SQLBinaryExpression(
                left: self.field(field),
                op: self.method(method),
                right: self.value(value)
            )
        case .custom(let any):
            #warning("TODO:")
            return any as! SQLExpression
        case .group(let filters, let relation):
            return SQLList(items: filters.map(self.filter), separator: self.relation(relation))
        }
    }
    
    private func relation(_ relation: DatabaseQuery.Filter.Relation) -> SQLExpression {
        switch relation {
        case .and: return SQLBinaryOperator.and
        case .or: return SQLBinaryOperator.or
        case .custom(let any): return any as! SQLExpression
        }
    }
    
    private func value(_ value: DatabaseQuery.Value) -> SQLExpression {
        switch value {
        case .bind(let encodable):
            return SQLBind(encodable)
        case .null:
            return SQLLiteral.null
        case .group(let values):
            return SQLGroupExpression(SQLList(items: values.map(self.value), separator: SQLRaw(", ")))
        default:
            #warning("TODO:")
            fatalError("\(value) not yet supported")
        }
    }
    
    private func method(_ method: DatabaseQuery.Filter.Method) -> SQLExpression {
        switch method {
        case .equality(let inverse):
            if inverse {
                return SQLBinaryOperator.notEqual
            } else {
                return SQLBinaryOperator.equal
            }
        case .subset(let inverse):
            if inverse {
                return SQLBinaryOperator.notIn
            } else {
                return SQLBinaryOperator.in
            }
        default:
            #warning("TODO:")
            fatalError("\(method) not yet supported")
        }
    }
}
