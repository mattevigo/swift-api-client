//
//  ApiClient.swift
//

import Foundation
import Combine
import os

let apiClientDefaultDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

let apiClientStandardHeaders = [
    "Content-Type": "application/json; charset=utf-8"
]

public typealias HttpHeaders = [String: String]

public typealias QueryParams = [String: String]

/// ``ApiClient`` is a class to perform Restful network calls on a standard Api environment.
public class ApiClient {
    
    /// Delegate of this ``ApiClient``
    public var networkMonitor: ApiClientNetworkMonitor?
    
    /// Delegate to handle the session
    public weak var sessionDelegate: ApiClientSessionDelegate?
    
    /// Base URL for all network calls
    internal let baseUrl: URL
    
    /// Default headers for all network calls
    internal let defaultHeaders: HttpHeaders
    
    /// Logger that will be used by this ``ApiClient``
    public var logger: Logger?
    
    internal let decoder: JSONDecoder
    internal let encoder: JSONEncoder

    public init(baseUrl: String, defaultHeaders: HttpHeaders) {
        guard let url = URL(string: baseUrl) else {
            fatalError("Invalid base URL")
        }
        
        self.baseUrl = url
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = apiClientDefaultDateFormat

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .formatted(dateFormatter)

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .formatted(dateFormatter)
        
        self.defaultHeaders = defaultHeaders
    }
    
    // swiftlint:disable function_body_length
    // swiftlint:disable cyclomatic_complexity

    /// Perform a generic network call and get the publisher using raw data for body and response
    /// - Parameters:
    ///   - path: the pathe for the endpoint (note: each path MUST have  '/' prefix)
    ///   - method: the HttpMethod to use in this call
    ///   - queryParams: query parameters for the url
    ///   - headers: all required headers for the request
    ///   - body: data to send in the body of the http request
    /// - Returns: a publisher that publish the desired Data or fails with an ``ApiError``
    public func call(_ path: String,
                     method: HttpMethod = .get,
                     queryParams: QueryParams? = nil,
                     headers: HttpHeaders? = nil,
                     bodyData: Data?) -> AnyPublisher<Data, ApiError> {

        guard self.pathIsValid(path),
              var request = buildRequestWith(
                  path: path,
                  method: method,
                  queryParams: queryParams,
                  headers: headers) else {
            return Fail(error: ApiError.invalidPath)
                .eraseToAnyPublisher()
        }

        if let body = bodyData {
            request.httpBody = body
            self.logger?.info("---> \(method.rawValue) \(path) - body: \(body.count) bytes")
            
        } else {
            self.logger?.info("---> \(method.rawValue) \(path) - body: empty")
        }

        // Uncommet to print headers
        self.logger?.debug("headers: \(request.allHTTPHeaderFields?.description ?? "n/a", align: .right(columns: 1))")

        return URLSession.shared
            .dataTaskPublisher(for: request)
            .mapError { ApiError.urlError($0) }
            .tryMap { data, response in
                guard let response = response as? HTTPURLResponse else {
                    throw ApiError.unreadableResponse
                }

                self.logger?.info("<--- \(method.rawValue) \(path) - \(response.statusCode)")
                
                // Notify the delegate
                self.networkMonitor?.client(self, didReceiveResponse: response, body: data)

                return data
            }
            .mapError { error -> ApiError in
                guard let error = error as? ApiError else {
                    return .unknownError(error)
                }
                
                return error
            }
            .catch { error -> AnyPublisher<Data, ApiError> in
                // Notify the delegate
                self.networkMonitor?.client(self, didError: error)
                
                self.logger?.error("    \(error)")
                
                return Fail(outputType: Data.self, failure: error)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // swiftlint:enable function_body_length
    // swiftlint:enable cyclomatic_complexity

    /// Perform a generic call with body on bothr request and response
    /// - Parameters:
    ///   - path: path of the request url
    ///   - method: http method to use for the request (GET by default)
    ///   - queryParams: additional query parameters to add
    ///   - customHeaders: additional http header to add
    ///   - body: encodable body of the request of type B
    /// - Returns: a publisher that completes with the expected data of type T or fails with an ``ApiError``
    public func call<B: Encodable, T: Decodable>(_ path: String,
                                                 method: HttpMethod = .get,
                                                 queryParams: QueryParams? = nil,
                                                 customHeaders: HttpHeaders? = nil,
                                                 body: B) -> AnyPublisher<T, ApiError> {
        var bodyData: Data?
        do {
            bodyData = try self.encoder.encode(body)
            self.logger?.debug("request: \(String(data: bodyData ?? Data(), encoding: .utf8) ?? "na")")
            
        } catch let error {
            self.logger?.error("invalid request body: \(error)")
            return Fail(error: ApiError.invalidRequestBody)
                .eraseToAnyPublisher()
        }

        return self.call(path, 
                         method: method,
                         queryParams: queryParams,
                         headers: self.extendRequestHeaders(with: customHeaders),
                         bodyData: bodyData)
            .decode(type: T.self, decoder: self.decoder)
            .mapError { error -> ApiError in
                self.logger?.error("\(error)")
                guard let error = error as? ApiError else {
                    return ApiError.unreadableResponse
                }

                return error
            }
            .eraseToAnyPublisher()
    }

    /// Perform a generic call with body only in the request
    /// - Parameters:
    ///   - path: path of the request url
    ///   - method: http method to use for the request (GET by default)
    ///   - queryParams: additional query parameters to add
    ///   - customHeaders: additional http header to add
    ///   - body: encodable body of the request of type B
    /// - Returns: a publisher that completes without publishing data or fails with an ``ApiError``
    public func call<B: Encodable>(_ path: String,
                                   method: HttpMethod = .get,
                                   queryParams: QueryParams? = nil,
                                   customHeaders: HttpHeaders? = nil,
                                   body: B) -> AnyPublisher<Void, ApiError> {
        var bodyData: Data?
        do {
            bodyData = try self.encoder.encode(body)
        } catch let error {
            self.logger?.error("encoding error: \(error)")
            
            // Notify the delegate
            self.networkMonitor?.client(self, didError: .invalidRequestBody)
            
            return Fail(error: ApiError.invalidRequestBody)
                .eraseToAnyPublisher()
        }
        
        return self.call(path,
                         method: method,
                         queryParams: queryParams,
                         headers: self.extendRequestHeaders(with: customHeaders),
                         bodyData: bodyData)
        .map { _ in }
        .eraseToAnyPublisher()
    }
    
    /// Perform a generic call with body only in the response
    /// - Parameters:
    ///   - path: path of the request url
    ///   - method: http method to use for the request (GET by default)
    ///   - queryParams: additional query parameters to add
    ///   - customHeaders: additional http header to add
    /// - Returns: a publisher that completes without publishing data or fails with an ``ApiError``
    public func call<T: Decodable>(_ path: String,
                                   method: HttpMethod = .get,
                                   queryParams: QueryParams? = nil,
                                   customHeaders: HttpHeaders? = nil) -> AnyPublisher<T, ApiError> {
        
        return self.call(path,
                         method: method,
                         queryParams: queryParams,
                         headers: self.extendRequestHeaders(with: customHeaders),
                         bodyData: nil)
        .decode(type: T.self, decoder: self.decoder)
        .mapError { error -> ApiError in
            self.logger?.error("\(error)")
            guard let error = error as? ApiError else {
                return ApiError.unreadableResponse
            }
            
            return error
        }
        .eraseToAnyPublisher()
    }
}

// MARK: Utility

extension ApiClient {
    
    /// Get the headers for http calls
    var headers: HttpHeaders {
        var h = self.defaultHeaders
        
        // Add session headers
        if let sessionHeaders = self.sessionDelegate?.clientDidRequestSessionHeaders(self) {
            h.merge(sessionHeaders) { a, b in b }
        }

        return h
    }

    /// Build a set of headers for the requesta by adding custom header to the default headers set
    /// - Parameter customHeaders: custom header to add to the request
    /// - Returns: a dictionary that contains all the headers
    fileprivate func extendRequestHeaders(with customHeaders: HttpHeaders?) -> HttpHeaders {
        if let customHeaders = customHeaders {
            return self.headers.merging(customHeaders) { a, b in b }
        } else {
            return self.headers
        }
    }
    
    /// Evaluate if a path is valid
    /// - Parameter path: path to evaluate
    /// - Returns: true if the path is valid, fals otherwise
    func pathIsValid(_ path: String) -> Bool {
        path.first == "/"
    }
    
    /// Build a ``URLRequest`` for a given path with empty http body
    /// - Parameters:
    ///   - path: path of the request
    ///   - method: http method of the call
    ///   - queryParams: qquery parameters for the url
    ///   - headers: all required headers for the request
    /// - Returns: an ``URLRequest`` built with the parameters specified
    func buildRequestWith(path: String,
                          method: HttpMethod = .get,
                          queryParams: QueryParams? = nil,
                          headers: HttpHeaders? = nil) -> URLRequest? {

        guard var components = URLComponents(url: self.baseUrl, resolvingAgainstBaseURL: true) else {
            self.logger?.warning("cannot build request, invalid base url \(self.baseUrl)")
            return nil
        }
        
        components.path = components.path + path
        components.queryItems = queryParams?.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add headers to request
        headers?.forEach {
            request.addValue($0.value, forHTTPHeaderField: $0.key)
        }

        return request
    }

    /// Build a ``URLRequest`` for a given path with a json http body
    /// - Parameters:
    ///   - path: path of the request
    ///   - method: http method of the call
    ///   - queryParams: qquery parameters for the url
    ///   - headers: all required headers for the request
    ///   - data: an ``Encodable`` object to send as http body
    /// - Returns: an ``URLRequest`` built with the parameters specified
    func buildRequestWith<T: Encodable>(path: String,
                                        method: HttpMethod = .get,
                                        queryParams: QueryParams? = nil,
                                        headers: HttpHeaders? = nil,
                                        data: T) -> URLRequest? {

        var request = self.buildRequestWith(path: path, method: method, queryParams: queryParams, headers: headers)

        guard let body = try? encoder.encode(data) else {
            return nil
        }

        request?.httpBody = body

        return request
    }
}
