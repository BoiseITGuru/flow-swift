//
//  File.swift
//
//
//  Created by Hao Fu on 20/6/2022.
//

import Foundation

extension Flow {
    enum AccessEndpoint {
        case ping
        case getBlockHeaderByHeight(height: UInt64)
        case getBlockHeaderById(id: Flow.ID)
        case getLatestBlockHeader
        case getLatestBlock(sealed: Bool)
        case getBlockById(id: Flow.ID)
        case getBlockByHeight(height: UInt64)
        case getCollectionById(id: Flow.ID)
        case sendTransaction(transaction: Flow.Transaction)
        case getTransactionById(id: Flow.ID)
        case getTransactionResultById(id: Flow.ID)
        case getAccountAtLatestBlock(address: Flow.Address)
        case getAccountByBlockHeight(address: Flow.Address, height: UInt64)
        case executeScriptAtLatestBlock(script: Flow.Script, arguments: [Flow.Argument])
        case executeScriptAtBlockId(script: Flow.Script, blockId: Flow.ID, arguments: [Flow.Argument])
        case executeScriptAtBlockHeight(script: Flow.Script, height: UInt64, arguments: [Flow.Argument])
        case getEventsForHeightRange(type: String, range: ClosedRange<UInt64>)
        case getEventsForBlockIds(type: String, ids: Set<Flow.ID>)
        case getNetworkParameters
        case getLatestProtocolStateSnapshot
    }
}

extension Flow.AccessEndpoint: TargetType {
    
    var task: Task {
        switch self {
        case .ping, .getLatestBlockHeader:
            return .requestParameters(["height": "sealed"])
        case let .getBlockHeaderByHeight(height: height):
            return .requestParameters(["height": String(height)])
        case .getBlockById:
            return .requestParameters(["expand" : "payload"])
        case let .getBlockByHeight(height):
            return .requestParameters(["height": String(height), "expand" : "payload"])
        case let .getLatestBlock(sealed: sealed):
            return .requestParameters(["height" : sealed ? "sealed" : "finalized", "expand" : "payload"])
        case .getAccountAtLatestBlock:
            return .requestParameters(["block_height" : "sealed", "expand" : "contracts,keys"])
        case let .getAccountByBlockHeight(_, height):
            return .requestParameters(["block_height" : String(height), "expand" : "contracts,keys"])
        case .getCollectionById:
            return .requestParameters(["expand" : "transactions"])
        case let .executeScriptAtLatestBlock(script, arguments):
            return .requestParameters(["block_height" : "sealed"], body: Flow.ScriptRequest(script: script, arguments: arguments))
        case let .executeScriptAtBlockHeight(script, height, arguments):
            return .requestParameters(["block_height" : String(height)], body: Flow.ScriptRequest(script: script, arguments: arguments))
        case let .executeScriptAtBlockId(script, id, arguments):
            return .requestParameters(["block_id" : id.hex], body: Flow.ScriptRequest(script: script, arguments: arguments))
        case let .sendTransaction(tx):
            return .requestParameters([:], body: tx)
        default:
            return .requestParameters()
        }
    }

    var method: Method {
        switch self {
        case .ping, .getBlockByHeight, .getBlockHeaderById:
            return .GET
        case .sendTransaction,
             .executeScriptAtBlockHeight,
             .executeScriptAtLatestBlock,
             .executeScriptAtBlockId:
            return .POST
        default:
            return .GET
        }
    }

    var baseURL: URL {
        flow.chainID.defaultHTTPNode.url!
    }

    var path: String {
        switch self {
        case .ping,
                .getLatestBlockHeader,
                .getBlockByHeight,
                .getLatestBlock:
            return "/v1/blocks"
        case let .getBlockHeaderById(id):
            return "/v1/blocks/\(id.hex)"
        case let .getBlockById(id):
            return "/v1/blocks/\(id.hex)"
        case let .getAccountAtLatestBlock(address):
            return "/v1/accounts/\(address.hex)"
        case let .getAccountByBlockHeight(address, _):
            return "/v1/accounts/\(address.hex)"
        case let .getTransactionResultById(id):
            return "/v1/transaction_results/\(id.hex)"
        case let .getTransactionById(id):
            return "/v1/transactions/\(id.hex)"
        case let .getCollectionById(id):
            return "/v1/collections/\(id.hex)"
        case .executeScriptAtLatestBlock,
                .executeScriptAtBlockId,
                .executeScriptAtBlockHeight:
            return "/v1/scripts"
        case .sendTransaction:
            return "/v1/transactions"
        default:
            return ""
        }
    }

    var headers: [String: String]? {
        return ["Content-Type": "application/json"]
    }
}

public enum Method: String {
    case GET
    case POST
}

public protocol TargetType {
    /// The target's base `URL`.
    var baseURL: URL { get }

    /// The path to be appended to `baseURL` to form the full `URL`.
    var path: String { get }

    /// The HTTP method used in the request.
    var method: Method { get }

    /// The type of HTTP task to be performed.
    var task: Task { get }

    /// The headers to be used in the request.
    var headers: [String: String]? { get }
}

public enum Task {

    /// A requests body set with encoded parameters.
    case requestParameters(_ parameters: [String: String]? = nil, body: Encodable? = nil)
}

struct AnyEncodable: Encodable {

    private let encodable: Encodable

    public init(_ encodable: Encodable) {
        self.encodable = encodable
    }

    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}
