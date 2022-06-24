//
//  FlowTransaction + Signer
//
//  Copyright 2022 Outblock Pty Ltd
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

public extension Flow {
    /// Sign the unsigned transaction with a list of `FlowSigner`
    /// - parameters:
    ///     - unsignedTransaction: The transaction to be signed
    ///     - signers: A list of `FlowSigner` to sign the transaction
    /// - returns: The signed transaction
    func signTransaction(unsignedTransaction: Flow.Transaction, signers: [FlowSigner]) async throws -> Flow.Transaction {
        var tx = unsignedTransaction
        return try await tx.sign(signers: signers)
    }
}

public extension Flow.Transaction {
    /// Sign (Mutate) the payload of Flow Transaction with a list of `FlowSigner`
    /// - parameters:
    ///     - signers: A list of `FlowSigner` to sign the transaction
    /// - returns: The `Flow.Transaction` itself.
    @discardableResult
    mutating func signPayload(signers: [FlowSigner]) async throws -> Flow.Transaction {
        guard let signablePlayload = signablePlayload else {
            throw Flow.FError.invaildPlayload
        }

        func findSigners(address: Flow.Address, signers: [FlowSigner]) -> [FlowSigner]? {
            return signers.filter { $0.address == address }
        }

        // Sign with the proposal key first.
        // If proposer is same as payer, we skip this step
        if proposalKey.address != payer {
            guard let signers = findSigners(address: proposalKey.address, signers: signers) else {
                throw Flow.FError.missingSigner
            }
            for signer in signers {
                let signature = try await signer.sign(signableData: signablePlayload)
                addPayloadSignature(address: signer.address,
                                    keyIndex: signer.keyIndex,
                                    signature: signature)
            }
        }

        // Sign the transaction with each authorizer
        for authorizer in authorizers {
            if proposalKey.address == authorizer {
                continue
            }

            if payer == authorizer {
                continue
            }

            guard let signers = findSigners(address: authorizer, signers: signers) else {
                throw Flow.FError.missingSigner
            }

            for signer in signers {
                let signature = try await signer.sign(signableData: signablePlayload)
                addPayloadSignature(address: authorizer,
                                    keyIndex: signer.keyIndex,
                                    signature: signature)
            }
        }

        return self
    }

    /// Sign (Mutate) the envelope of Flow Transaction with a list of `FlowSigner`
    /// - parameters:
    ///     - signers: A list of `FlowSigner` to sign the transaction
    /// - returns: The `Flow.Transaction` itself.
    @discardableResult
    mutating func signEnvelope(signers: [FlowSigner]) async throws -> Flow.Transaction {
        guard let signableEnvelope = signableEnvelope else {
            throw Flow.FError.invaildEnvelope
        }

        func findSigners(address: Flow.Address, signers: [FlowSigner]) -> [FlowSigner]? {
            return signers.filter { $0.address == address }
        }

        guard let signers = findSigners(address: payer,
                                        signers: signers)
        else {
            throw Flow.FError.missingSigner
        }

        // Sign the transaction with payer
        for signer in signers {
            let signature = try await signer.sign(signableData: signableEnvelope)
            addEnvelopeSignature(address: payer,
                                 keyIndex: signer.keyIndex,
                                 signature: signature)
        }
        return self
    }

    // TODO: Replace it with the combination of `signPayload` and `signEnvelope`

    /// Sign (Mutate) unsigned Flow Transaction with a list of `FlowSigner`
    /// - parameters:
    ///     - signers: A list of `FlowSigner` to sign the transaction
    /// - returns: The `Flow.Transaction` itself.
    @discardableResult
    mutating func sign(signers: [FlowSigner]) async throws -> Flow.Transaction {
        try await signPayload(signers: signers)
        try await signEnvelope(signers: signers)
        return self
    }
}
