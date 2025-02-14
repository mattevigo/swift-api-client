//
//  ApiError.swift
//
//
//  Created by Matteo Vigoni on 22/04/22.
//

import Foundation

public enum ApiError: Error {
    case invalidPath
    case invalidRequestBody
    case urlError(URLError)
    case authenticationRequired
    case apiThrottling
    case downForMaintenance
    case httpError(Int, Data)
    case unreadableResponse
    case unknownError(Error)
}
