# SwiftApiClient
Flexible api client based on Combine.

SwiftApiClient is a generic REST client written in Swift for interacting with APIs. It leverages Apple's Combine framework for reactive programming, making it easy to manage asynchronous network calls, JSON encoding/decoding, and HTTP request handling. This package provides a simple, unified API to seamlessly integrate RESTful communication into your Swift projects.

## Features

- **Combine Integration**  
  Fully built with Combine, allowing you to work with publishers and subscribers for reactive network calls.

- **Generic Network Calls**  
  Perform HTTP requests (GET, POST, PUT, DELETE, etc.) using a unified API that returns Combine publishers.

- **JSON Encoding & Decoding**  
  Automatically handles JSON encoding/decoding using customizable `JSONEncoder` and `JSONDecoder` instances. Uses the standard date format (`yyyy-MM-dd'T'HH:mm:ss.SSS'Z'`).

- **Customizable Headers & Query Parameters**  
  Easily merge default headers with custom headers and add query parameters to each request.

- **Logging**  
  Integrates with Apple's `os.Logger` for detailed logging at various levels (info, debug, error).

- **Delegate Support**  
  Supports delegates (`ApiClientDelegate` and `ApiClientSessionDelegate`) for custom session behavior and for receiving notifications on responses and errors.

## Installation

Add SwiftApiClient to your project using the Swift Package Manager. In your `Package.swift`, add:

```swift
dependencies: [
    .package(url: "https://github.com/mattevigo/SwiftApiClient.git", from: "1.0.0")
]
```

## Usage

Initialize the client and optionally the Logger

```swift
// Initialize the ApiClient with a base URL and default headers
self.client = ApiClient(baseUrl: "https://rickandmortyapi.com/api", defaultHeaders: [:])

// Assign a logger to capture detailed logs
self.client.logger = Logger(subsystem: "SwiftApiClient", category: "DemoApp")
```

SwiftApiClient allow you to simply define your types of the domain aand cal the api inferring the type of the response.
For example you can create a simple method to get all the character returned by the rickandmortyapi like wise we've done in the Demo app:

```swift
struct Response: Decodable {
    let info: Info
}

struct Info: Decodable {
    let count: Int
    let pages: Int

    // All other properties...
}
```

Define a method that calls the API:

```swift
func getCharacters() -> AnyPublisher<Response, ApiError> {
  self.client.call("/character")
}
```

Below is an example demonstrating how to create an instance of ApiClient, configure logging, and perform a network call using Combine:

```swift
// Make a network call using Combine to fetch characters
self.cancellable = self.getCharacters()
    .print("getCharacters")
    .sink(receiveCompletion: { completion in
        // Handle completion (e.g., check for errors)
    }, receiveValue: { response in
        // Process the received response
        print(response)
    })
```

Or you can simply use the ``async()`` method to call the api in an asynchronous context and use the ``Publisher.setResultType()`` utility method function to specified the expected returned type

```swift 
// Specify the type returned
self.client.call("/character")
    .setResultType(to: Response.self)
    .print("Direct call")
    .sink(receiveCompletion: { completion in
        
    }, receiveValue: { response in
        print(response)
    })
    .store(in: &self.cancellables)
```

## API Overview

The main functionality of SwiftApiClient is implemented in the ApiClient.swift file. Key methods include:

- **call(_:method:queryParams:headers:bodyData:)**
    Performs a generic network call and returns a publisher emitting raw Data or an ApiError.

- **call<B: Encodable, T: Decodable>(_:method:queryParams:customHeaders:body:)**
    Sends an encodable body and decodes the response into a specified type, leveraging Combine for asynchronous operations.

- **call<B: Encodable>(_:method:queryParams:customHeaders:body:)**
    Sends an encodable body when no response body is expected, returning a Combine publisher that completes without emitting data.

- **call<T: Decodable>(_:method:queryParams:customHeaders:)**
    Executes a call without a request body but expects a decoded response, processing the response through Combine's publisher.

SwiftApiClient also handles error management, logging, and delegate notifications, ensuring robust and versatile network communication.

## Session Delegate

You can specify a custom ``ApiClientSessionDelegate`` to provide custom session related headers for the ``ApiClient`` in response to the only protocol method

```swift
func clientDidRequestSessionHeaders(_ client: ApiClient) -> HttpHeaders?
```

The headers returned will be included in the network call.

## Network Monitor

In addiction you can set a class that implements the protocol ``ApiClientNetworkMonitor`` to moitor all network calls of an ``ApiClient``. This is useful if you have to handle session and refresh tokens or simply for logging.

## Publisher+Async Intgration

SwiftApiClient extends the Combine `Publisher` by adding the `async()` method, allowing you to use async/await to obtain the first emitted value from a publisher.
