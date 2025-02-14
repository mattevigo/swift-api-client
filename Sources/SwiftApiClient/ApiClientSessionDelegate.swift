//
//  ApiClientSessionDelegate.swift
//  SwiftApiClient
//
//  Created by Matteo Vigoni on 13/02/2025.
//

import Foundation

public protocol ApiClientSessionDelegate: AnyObject {
    
    /// Request a set of session headers for the given ``ApiClient``
    /// - Parameter client: the ``ApiClient`` that requests the session headers
    /// - Returns: the set of session headers for the given ``ApiClient``
    func clientDidRequestSessionHeaders(_ client: ApiClient) -> HttpHeaders?
}
