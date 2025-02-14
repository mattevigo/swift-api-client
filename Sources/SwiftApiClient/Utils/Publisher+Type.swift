//
//  Publisher+Type.swift
//  SwiftApiClient
//
//  Created by Matteo Vigoni on 13/02/2025.
//

import Combine

extension Publisher {
    
    /// Converts the output type of the publisher to the specified type.
    /// - Returns: An `AnyPublisher` that emits values of the specified type while preserving the original failure type.
    public func setResultType<T>(to type: T.Type) -> AnyPublisher<T, Failure> where Output == T {
        return self.eraseToAnyPublisher()
    }
}
