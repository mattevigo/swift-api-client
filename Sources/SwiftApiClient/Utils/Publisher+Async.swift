//
//  Publisher+Async.swift
//  SwiftApiClient
//
//  Created by Matteo Vigoni on 13/02/2025.
//

import Combine

public enum AsyncError: Error {
    case finishedWithoutValue
}

extension Publisher {

    /// Create an async method for the current publisher to get the first published element from upstream asynchronously
    /// - Returns: the first published element from upstream
    public func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var finishedWithoutValue = true
            cancellable = first()
                .sink { result in
                    switch result {
                    case .finished:
                        if finishedWithoutValue {
                            continuation.resume(throwing: AsyncError.finishedWithoutValue)
                        }
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                    cancellable = nil
                } receiveValue: { value in
                    finishedWithoutValue = false
                    continuation.resume(with: .success(value))
                }
        }
    }
}
