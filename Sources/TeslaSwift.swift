//
//  TeslaSwift.swift
//  TeslaSwift
//
//  Created by Joao Nunes on 04/03/16.
//  Copyright © 2016 Joao Nunes. All rights reserved.
//

import Foundation
import ObjectMapper
import BrightFutures
import Alamofire

public enum TeslaError:ErrorType {
	case NetworkError(error:NSError)
	case JSONParsingError(error:NSError)
	case AuthenticationRequired
}

public class TeslaSwift {
	
	public static let defaultInstance = TeslaSwift()
	
	var token:AuthToken?
	private var email:String?
	private var password:String?
	
	public var useMockServer = false
	
	var baseURL:String {
		if useMockServer {
			return "https://private-anon-6ec07f49d-timdorr.apiary-mock.com"
		} else {
			return "https://owner-api.teslamotors.com"
		}
	}
}

extension TeslaSwift {
	
	/**
	Performs the authentition with the Tesla API
	
	You only need to call this once. The token will be stored and your credentials.
	If the token expires your credentials will be reused.
	
	- parameter email:      The email address.
	- parameter password:   The password.
	
	- returns: A Future with the AuthToken.
	*/

	public func authenticate(email:String, password:String) -> Future<AuthToken,TeslaError> {
		
		self.email = email
		self.password = password
		
		let url = NSURL(string: baseURL.stringByAppendingString("/oauth/token"))!

		let body = AuthTokenRequest()
		body.email = email
		body.password = password
		body.grantType = "password"
		body.clientSecret = "c75f14bbadc8bee3a7594412c31416f8300256d7668ea7e6e7f06727bfb9d220"
		body.clientID = "e4a9949fcfa04068f59abb5a658f2bac0a3428e4652315490b659d5ab3f35a9e"
		
		return request(.POST, url: url, body: body)
			.andThen { (result) -> Void in
			self.token = result.value
		}
		
	}
	
	/**
	Fetchs the list of your vehicles including not delivered ones
	
	- returns: A Future with an array of Vehicles.
	*/
	public func getVehicles() -> Future<[Vehicle],TeslaError> {
		
		let url = NSURL(string: baseURL.stringByAppendingString("/api/1/vehicles"))!
		
		return checkAuthentication().flatMap { (token) -> Future<[Vehicle], TeslaError> in
			self.request(.GET, url: url, body: nil, keyPath: "response")
		}
		
	}
	
}

extension TeslaSwift {
	
	func checkToken() -> Future<Bool,TeslaError> {
		
		if let token = self.token {
			return Future<Bool,TeslaError>(value: token.isValid)
		} else {
			return Future<Bool,TeslaError>(value:false)
		}
	}
	
	func checkAuthentication() -> Future<AuthToken,TeslaError> {
		
		return checkToken().flatMap { (value) -> Future<AuthToken, TeslaError> in
			
			if (value) {
				return Future<AuthToken, TeslaError>(value: self.token!)
			} else {
				if let email = self.email, password = self.password {
					return self.authenticate(email, password: password)
				} else {
					return Future<AuthToken, TeslaError>(error: .AuthenticationRequired)
				}
				
			}
		}
	}
	
	func request<T:Mappable>(method: Alamofire.Method, url:NSURL, body:Mappable?, keyPath:String? = nil) -> Future<T,TeslaError> {
		
		return prepareRequest(method, url: url, body: body).responseObjectFuture(keyPath)
	}
	func request<T:Mappable>(method: Alamofire.Method, url:NSURL, body:Mappable?, keyPath:String? = nil) -> Future<[T],TeslaError> {
		
		return prepareRequest(method, url: url, body: body).responseObjectFuture(keyPath)
	}
	
	func prepareRequest(method: Alamofire.Method, url:NSURL, body:Mappable?) -> Request {
		
		let request = NSMutableURLRequest(URL: url)
		request.HTTPMethod = method.rawValue
		
		if let token = self.token?.accessToken {
			request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}
		
		if let body = body {
			let jsonObject = body.toJSON()
			request.HTTPBody = try? NSJSONSerialization.dataWithJSONObject(jsonObject, options: [])
			request.setValue("application/json", forHTTPHeaderField: "content-type")
		}
		let alamonfireRequest = Alamofire.request(request)
		
		print("Request: \(alamonfireRequest)")
		if let body = body {
			print("Request Body: \(body.toJSONString(true)!)")
		}
		
		return alamonfireRequest
	}
	
}