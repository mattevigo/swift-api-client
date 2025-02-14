//
//  RestClientDelegate.swift
//

import Foundation

public protocol ApiClientNetworkMonitor: AnyObject {
    
    /// Called each time the monitored ``ApiClient`` receives an ``HttpResponse``
    /// - Parameters:
    ///   - client: the ``ApiClient`` that received this response
    ///   - response: the ``HttpResponse`` received
    ///   - body: data in the response
    func client(_ client: ApiClient, didReceiveResponse response: HTTPURLResponse, body: Data?)
    
    /// Called each time the monitored ``ApiClient`` recieves an error, commonly a connection issue
    /// - Parameters:
    ///   - client: the ``ApiClient`` that received the error
    ///   - error: ``ApiError`` recieved
    func client(_ client: ApiClient, didError error: ApiError)
}
