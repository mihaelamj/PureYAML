public extension PureYAML.Tagged {
    /// Caller-owned conversion policy from tagged YAML nodes into typed values.
    struct Constructor<Output>: Sendable {
        var handlers: [Handler<Output>]
        var fallback: (@Sendable (Node, ConstructionContext<Output>) throws -> Output)?

        public init() {
            handlers = []
            fallback = nil
        }

        /// Constructs one tagged node from the root path.
        public func construct(_ node: Node) throws -> Output {
            try construct(root: node, subject: node, path: .root)
        }

        /// Registers a scalar handler for an exact tag.
        public func constructingScalar(
            tag: Tag,
            _ build: @escaping @Sendable (Scalar, ConstructionContext<Output>) throws -> Output,
        ) -> Self {
            appending(.init(tag: tag, kind: .scalar) { node, context in
                guard case let .scalar(scalar) = node else {
                    throw PureYAML.Tagged.ConstructionError.kindMismatch(
                        tag: tag,
                        expected: [.scalar],
                        actual: node.kind,
                        path: context.path,
                    )
                }
                return try build(scalar, context)
            })
        }

        /// Registers a sequence handler for an exact tag.
        public func constructingSequence(
            tag: Tag,
            _ build: @escaping @Sendable (Sequence, ConstructionContext<Output>) throws -> Output,
        ) -> Self {
            appending(.init(tag: tag, kind: .sequence) { node, context in
                guard case let .sequence(sequence) = node else {
                    throw PureYAML.Tagged.ConstructionError.kindMismatch(
                        tag: tag,
                        expected: [.sequence],
                        actual: node.kind,
                        path: context.path,
                    )
                }
                return try build(sequence, context)
            })
        }

        /// Registers a mapping handler for an exact tag.
        public func constructingMapping(
            tag: Tag,
            _ build: @escaping @Sendable (Mapping, ConstructionContext<Output>) throws -> Output,
        ) -> Self {
            appending(.init(tag: tag, kind: .mapping) { node, context in
                guard case let .mapping(mapping) = node else {
                    throw PureYAML.Tagged.ConstructionError.kindMismatch(
                        tag: tag,
                        expected: [.mapping],
                        actual: node.kind,
                        path: context.path,
                    )
                }
                return try build(mapping, context)
            })
        }

        /// Registers an explicit fallback for nodes with no matching tag handler.
        public func fallingBackTo(
            _ build: @escaping @Sendable (Node, ConstructionContext<Output>) throws -> Output,
        ) -> Self {
            var copy = self
            copy.fallback = build
            return copy
        }
    }
}

extension PureYAML.Tagged.Constructor {
    struct Handler<Value> {
        var tag: PureYAML.Tagged.Tag
        var kind: PureYAML.Tagged.NodeKind
        var build: @Sendable (
            PureYAML.Tagged.Node,
            PureYAML.Tagged.ConstructionContext<Value>,
        ) throws -> Value
    }

    func construct(
        root: PureYAML.Tagged.Node,
        subject: PureYAML.Tagged.Node,
        path: PureYAML.Validation.Path,
    ) throws -> Output {
        let context = PureYAML.Tagged.ConstructionContext<Output>(
            root: root,
            subject: subject,
            path: path,
        ) { node, childPath in
            try construct(root: root, subject: node, path: childPath)
        }

        if let tag = subject.tag {
            let matches = handlers.filter { $0.tag == tag }
            if let match = matches.first(where: { $0.kind == subject.kind }) {
                return try match.build(subject, context)
            }
            if !matches.isEmpty {
                throw PureYAML.Tagged.ConstructionError.kindMismatch(
                    tag: tag,
                    expected: matches.map(\.kind),
                    actual: subject.kind,
                    path: path,
                )
            }
        }

        if let fallback {
            return try fallback(subject, context)
        }

        throw PureYAML.Tagged.ConstructionError.noConstructor(
            tag: subject.tag,
            kind: subject.kind,
            path: path,
        )
    }

    func appending(_ handler: Handler<Output>) -> Self {
        var copy = self
        copy.handlers.removeAll { existing in
            existing.tag == handler.tag && existing.kind == handler.kind
        }
        copy.handlers.append(handler)
        return copy
    }
}
