//
//  BaseBeaconPluginTests.swift
//  PlayerUI_Tests
//
//  Created by Harris Borawski on 3/11/21.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import XCTest
import JavaScriptCore
@testable import PlayerUI
@testable import PlayerUIBaseBeaconPlugin

class BPPlugin: JSBasePlugin {
    override open func setup(context: JSContext) {
        
    }
}

class BaseBeaconPluginTests: XCTestCase {
    func testBundleLoadsSymbols() {
        let context = JSContext()!
        
        let plugin = BaseBeaconPlugin<DefaultBeacon>() { _ in }
        
        plugin.context = context
        
        // as accessed on main from beacon-plugin.prod.js
        XCTAssertFalse(context.objectForKeyedSubscript("BeaconPlugin").objectForKeyedSubscript("BeaconPlugin").isUndefined)
        XCTAssertFalse(context.objectForKeyedSubscript("BeaconPlugin").objectForKeyedSubscript("BeaconPluginSymbol").isUndefined)
    }
    func testBeaconPluginAppliesContextToPlugins() {
        let context = JSContext()!
        JSUtilities.polyfill(context)
        let bpp = BPPlugin(fileName: "", pluginName: "")
        
        let plugin = BaseBeaconPlugin<DefaultBeacon>(plugins: [bpp]) { _ in }
        plugin.context = context
        
        XCTAssertNotNil(bpp.context)
    }
    
    func testBeaconFunction() {
        let context = JSContext()!
        JSUtilities.polyfill(context)
        
        let beaconed = expectation(description: "Beacon sent")
        
        let plugin = BaseBeaconPlugin<DefaultBeacon>(plugins: []) { _ in beaconed.fulfill() }
        plugin.context = context
        
        plugin.beacon(assetBeacon: AssetBeacon(action: "action", element: "element", asset: BeaconableAsset(id: "id")))
        wait(for: [beaconed], timeout: 1)
    }
    
    func testBeaconPluginStringData() {
        let context = JSContext()!
        JSUtilities.polyfill(context)
        
        let expectation = XCTestExpectation(description: "beacon callback called")
        let plugin = BaseBeaconPlugin<DefaultBeacon>( onBeacon: { (beacon) in
            XCTAssertEqual(beacon.assetId, "test")
            XCTAssertEqual(beacon.element, BeaconElement.button.rawValue)
            switch beacon.data {
            case .string(let string):
                XCTAssertEqual(string, "example")
            default:
                XCTFail("beacon data was not a string")
            }
            expectation.fulfill()
        })
        plugin.context = context
        
        plugin.beacon(assetBeacon: AssetBeacon(
            action: BeaconAction.clicked.rawValue,
            element: BeaconElement.button.rawValue,
            asset: BeaconableAsset(id: "test"),
            data: .string(data: "example")
        ))
        wait(for: [expectation], timeout: 2)
    }
    
    func testBeaconPluginDictionaryData() {
        let context = JSContext()!
        JSUtilities.polyfill(context)
        
        let expectation = XCTestExpectation(description: "beacon callback called")
        let plugin = BaseBeaconPlugin<DefaultBeacon>(onBeacon: { (beacon) in
            XCTAssertEqual(beacon.assetId, "test")
            XCTAssertEqual(beacon.element, BeaconElement.button.rawValue)
            switch beacon.data {
            case .dictionary(let dict):
                XCTAssertEqual(dict, ["data": "example"])
            default:
                XCTFail("beacon data was not a dictionary")
            }
            expectation.fulfill()
        })
        plugin.context = context
        
        plugin.beacon(assetBeacon: AssetBeacon(
            action: BeaconAction.clicked.rawValue,
            element: BeaconElement.button.rawValue,
            asset: BeaconableAsset(id: "test"),
            data: .dictionary(data: ["data": "example"])
        ))
        wait(for: [expectation], timeout: 2)
    }
    
    func testBeaconPluginAnyDictionaryData() {
        let context = JSContext()!
        JSUtilities.polyfill(context)
        
        let expectation = XCTestExpectation(description: "beacon callback called")
        let plugin = BaseBeaconPlugin<DefaultBeacon>(onBeacon: { (beacon) in
            XCTAssertEqual(beacon.assetId, "test")
            XCTAssertEqual(beacon.element, BeaconElement.button.rawValue)
            switch beacon.data {
            case .anyDictionary(let dict):
                XCTAssertEqual(2, dict.keys.count)
                XCTAssertEqual("example", dict["data"] as? String)
                XCTAssertEqual(3, dict["value"] as? Double)
            default:
                XCTFail("beacon data was not anyDictionary")
            }
            expectation.fulfill()
        })
        plugin.context = context
        
        plugin.beacon(assetBeacon: AssetBeacon(
            action: BeaconAction.clicked.rawValue,
            element: BeaconElement.button.rawValue,
            asset: BeaconableAsset(id: "test"),
            data: .anyDictionary(data: ["data": "example", "value": 3])
        ))
        wait(for: [expectation], timeout: 2)
    }
    
    func testCancelSpecificBeaconsUsingHooks() {
        let context = JSContext()!
        JSUtilities.polyfill(context)
        
        let cancelBeaconHandler = expectation(description: "Cancel Beacon Handler called")
        let handlerExpectation = expectation(description: "Handler called")
        handlerExpectation.isInverted = true
        
        let handler = MockHandler()
        
        let plugin = BaseBeaconPlugin<DefaultBeacon>(plugins: []) { (beacon) in
            if handler.calls.isEmpty {
                handler.handle(beacon.viewId!, beacon.data)
                handlerExpectation.fulfill()
            }
        }
        
        plugin.context = context
        plugin.setup(context: context)
        
        plugin.beacon(assetBeacon: AssetBeacon(
            action: BeaconAction.clicked.rawValue,
            element: BeaconElement.button.rawValue,
            asset: BeaconableAsset(id: "test"),
            data: .string(data: "example")
        ))
        
        guard let hooks = plugin.hooks else {
            XCTFail("Hooks are not initialized")
            return
        }
        
        hooks.cancelBeacon.tap { (arg1: JSValue, arg2: JSValue) -> Bool in
            cancelBeaconHandler.fulfill()
            if let action = arg1.toDictionary()?["action"] as? String, action == BeaconAction.clicked.rawValue {
                return true
            }
            return false
        }
        
        wait(for: [handlerExpectation, cancelBeaconHandler], timeout: 10)
    }
    
    class MockHandler {
        var calls: [(String, Any?)] = []
        
        func handle(_ action: String, _ data: Any? = nil) {
            calls.append((action, data))
        }
        
    }
    
    func testBuildSpecificBeaconsUsingHooks() {
        let context = JSContext()!
        JSUtilities.polyfill(context)
        let buildBeaconHandler = expectation(description: "Build Beacon Handler called")
        let handlerExpectation = expectation(description: "Handler called")
        let handler = MockHandler()
        
        let plugin = BaseBeaconPlugin<DefaultBeacon>(plugins: []) { (beacon) in
            if handler.calls.isEmpty {
                handler.handle(beacon.viewId!, beacon.data)
                handlerExpectation.fulfill()
            }
        }
        
        plugin.context = context
        plugin.setup(context: context)
        
        plugin.beacon(assetBeacon: AssetBeacon(
            action: BeaconAction.clicked.rawValue,
            element: BeaconElement.button.rawValue,
            asset: BeaconableAsset(id: "test"),
            data: .string(data: "example")
        ))
        
        guard let hooks = plugin.hooks else {
            XCTFail("Hooks are not initialized")
            return
        }
        
        hooks.buildBeacon.tap { (arg1: JSValue, arg2: JSValue) -> JSValue? in
            buildBeaconHandler.fulfill()
            if let actionDict = arg1.toDictionary(),
               let action = actionDict["action"] as? String,
               action == BeaconAction.clicked.rawValue {
                handler.handle(action, actionDict)
                handlerExpectation.fulfill() // Fulfill the handler expectation
                return JSValue(object: actionDict, in: arg1.context)
            }
            return nil
        }
        
        wait(for: [handlerExpectation, buildBeaconHandler], timeout: 10)
        
        // Assert that the modified beacon data is received in the handler
        XCTAssertEqual(handler.calls.count, 1)
        
    }
    
}
