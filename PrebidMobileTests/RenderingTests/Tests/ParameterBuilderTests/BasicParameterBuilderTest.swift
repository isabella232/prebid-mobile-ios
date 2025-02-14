/*   Copyright 2018-2021 Prebid.org, Inc.
 
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
 
  http://www.apache.org/licenses/LICENSE-2.0
 
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
  */

import UIKit
import XCTest
@testable import PrebidMobile

class PBMBasicParameterBuilderTest: XCTestCase {
    
    private var logToFile: LogToFileLock?
    
    private var targeting: Targeting!
    
    override func setUp() {
        super.setUp()
        
        targeting = .shared
        targeting.parameterDictionary["foo"] = "bar"
    }
    
    override func tearDown() {
        logToFile = nil
        targeting.coppa = nil
        
        super.tearDown()
    }
    
    func testParameterBuilderBannerAUID() {
        
        //Create Builder
        let adConfiguration = AdConfiguration()
        adConfiguration.isInterstitialAd = false
        
        let sdkConfiguration = Prebid.mock
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        
        
        //Run Builder
        let bidRequest = PBMORTBBidRequest()
        builder.build(bidRequest)
        
        //Check Impression
        PBMAssertEq(bidRequest.imp.count, 1)
        guard let imp = bidRequest.imp.first else {
            XCTFail("No imp object")
            return
        }
        
        PBMAssertEq(imp.instl, 0)
        PBMAssertEq(imp.displaymanager, "prebid-mobile")
        PBMAssertEq(imp.displaymanagerver, "MOCK_SDK_VERSION")
        PBMAssertEq(imp.secure, 1)
        PBMAssertEq(imp.clickbrowser, 0)
        
        //Check banner
        guard let banner = imp.banner else {
            XCTFail("No banner object!")
            return
        }
        
        PBMAssertEq(banner.api, nil)
        
        //Check Regs
        XCTAssertNil(bidRequest.regs.coppa)
    }
    
    func testParameterBuilderExternalBrowser() {
        let adConfiguration = AdConfiguration()
        
        let sdkConfiguration = Prebid.mock
        sdkConfiguration.useExternalClickthroughBrowser = true
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        
        let bidRequest = PBMORTBBidRequest()
        builder.build(bidRequest)
        
        guard let imp = bidRequest.imp.first else {
            XCTFail("No imp object")
            return
        }
        
        PBMAssertEq(imp.clickbrowser, 1)
    }
    
    func testParameterBuilderInterstitialVAST() {
        let adUnit = InterstitialRenderingAdUnit.init(configID: "configId")
        adUnit.adFormats = [.video]
        let adConfiguration = adUnit.adUnitConfig.adConfiguration
        let parameters = VideoParameters()
        parameters.placement = .Interstitial
        parameters.linearity = 1
        adConfiguration.videoParameters = parameters
        
        //Run the Builder
        let sdkConfiguration = Prebid.mock
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        
        let bidRequest = PBMORTBBidRequest()
        builder.build(bidRequest)
        
        //Check that this is counted as an interstitial
        PBMAssertEq(bidRequest.imp.count, 1)
        guard let imp = bidRequest.imp.first else {
            XCTFail("No Imp object!")
            return
        }
        
        PBMAssertEq(imp.instl, 1)
        
        guard let video = imp.video else {
            XCTFail("No video object!")
            return
        }
        
        PBMAssertEq(video.mimes, PBMConstants.supportedVideoMimeTypes)
        PBMAssertEq(video.protocols, [2,5])
        PBMAssertEq(video.delivery!, [3])
        PBMAssertEq(video.pos, 7)
    }
    
    func testParameterBuilderDefaultInterstitialConfig() {
        var adUnit = BaseInterstitialAdUnit.init(configID: "configId")
        checkDefaultParametersForAdUnit(adConfiguration: adUnit.adUnitConfig.adConfiguration)
        
        adUnit = BaseInterstitialAdUnit.init(configID: "configId", minSizePerc: 0.2 as NSValue, eventHandler: InterstitialEventHandlerStandalone())
        checkDefaultParametersForAdUnit(adConfiguration: adUnit.adUnitConfig.adConfiguration)
        
        adUnit = BaseInterstitialAdUnit.init(configID: "configId", minSizePercentage: CGSize.zero)
        checkDefaultParametersForAdUnit(adConfiguration: adUnit.adUnitConfig.adConfiguration)
        
        adUnit = BaseInterstitialAdUnit.init(configID: "configId", minSizePercentage: CGSize.zero, eventHandler: InterstitialEventHandlerStandalone())
        checkDefaultParametersForAdUnit(adConfiguration: adUnit.adUnitConfig.adConfiguration)
        
        adUnit = BaseInterstitialAdUnit.init(configID: "configId", eventHandler: InterstitialEventHandlerStandalone())
        checkDefaultParametersForAdUnit(adConfiguration: adUnit.adUnitConfig.adConfiguration)
        
        let mediationAdUnit = MediationBaseInterstitialAdUnit.init(configId: "configId", mediationDelegate: MockMediationUtils(adObject: MockAdObject()))
        
        checkDefaultParametersForAdUnit(adConfiguration: mediationAdUnit.adUnitConfig.adConfiguration)
    }
    
    func testParameterBuilderOutstream() {
        let adConfiguration = AdConfiguration()
        adConfiguration.adFormats = [.video]
        adConfiguration.size = CGSize(width: 300, height: 250)
        
        //Run the Builder
        let sdkConfiguration = Prebid.mock
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        let bidRequest = PBMORTBBidRequest()
        builder.build(bidRequest)
        
        PBMAssertEq(bidRequest.imp.count, 1)
        guard let imp = bidRequest.imp.first else {
            XCTFail("No Imp object!")
            return
        }
        PBMAssertEq(imp.instl, 0)
        
        guard let video = imp.video else {
            XCTFail("No video object!")
            return
        }
        
        PBMAssertEq(video.mimes, PBMConstants.supportedVideoMimeTypes)
        PBMAssertEq(video.protocols, [2,5])
        XCTAssertNil(video.placement)
        
        PBMAssertEq(video.delivery!, [3])
        PBMAssertEq(video.pos, 7)
    }
    
    func testParameterBuilderCOPPANotSet() {
        let adConfiguration = AdConfiguration()
        adConfiguration.isInterstitialAd = false
        
        let sdkConfiguration = Prebid.mock
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        
        
        //Run Builder
        let bidRequest = PBMORTBBidRequest()
        builder.build(bidRequest)
        
        XCTAssertNil(bidRequest.regs.coppa)
    }
    
    func testParameterBuilderCOPPA() {
        self.testParameterBuilderCOPPA(value: nil, expectedRegValue: nil)
        self.testParameterBuilderCOPPA(value: 0, expectedRegValue: 0)
        self.testParameterBuilderCOPPA(value: 1, expectedRegValue: 1)
        self.testParameterBuilderCOPPA(value: 1.3, expectedRegValue: nil)
    }
    
    func testParameterBuilderCOPPA(value: NSNumber?, expectedRegValue: NSNumber?) {
        let adConfiguration = AdConfiguration()
        adConfiguration.isInterstitialAd = false
        
        if let coppa = value {
            targeting.coppa = coppa
        }
        
        let sdkConfiguration = Prebid.mock
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        
        
        //Run Builder
        let bidRequest = PBMORTBBidRequest()
        builder.build(bidRequest)
        
        PBMAssertEq(bidRequest.regs.coppa, expectedRegValue)
    }
    
    func testInvalidProperties() {
        let adConfiguration = AdConfiguration()
        
        let sdkConfiguration = Prebid.mock
        let bidRequest = PBMORTBBidRequest()
        
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        
        
        builder.build(bidRequest)
        
        logToFile = .init()
        
        builder.adConfiguration = nil
        builder.build(bidRequest)
        var log = Log.getLogFileAsString() ?? ""
        XCTAssertTrue(log.contains("Invalid properties"))
        
        logToFile = nil
        logToFile = .init()
        
        builder.adConfiguration = adConfiguration
        builder.sdkConfiguration = nil
        builder.build(bidRequest)
        log = Log.getLogFileAsString() ?? ""
        XCTAssertTrue(log.contains("Invalid properties"))
        
        logToFile = nil
        logToFile = .init()
        
        builder.sdkConfiguration = sdkConfiguration
        builder.sdkVersion = nil
        builder.build(bidRequest)
        log = Log.getLogFileAsString() ?? ""
        XCTAssertTrue(log.contains("Invalid properties"))
    }
    
    func testParameterBuilderVideoPlacement() {
        self.testParameterBuilderVideo(placement: nil,
                                       isInterstitial: false,
                                       expectedPlacement: 0)
        
        self.testParameterBuilderVideo(placement: nil,
                                       isInterstitial: true,
                                       expectedPlacement: 0)
    }
    
    func testParameterBuilderVideo(placement: Signals.Placement?,
                                   isInterstitial: Bool,
                                   expectedPlacement:Int) {
        
        var adConfiguration: AdConfiguration
        if (isInterstitial) {
            let adUnit = InterstitialRenderingAdUnit.init(configID: "configId")
            adUnit.adFormats = [.video]
            if let placement = placement {
                adUnit.videoParameters.placement = placement
            }
            adConfiguration = adUnit.adUnitConfig.adConfiguration
        } else {
            let adUnit = BannerView.init(frame: CGRect.zero, configID: "configId", adSize: CGSize.zero)
            adUnit.adFormat = .video
            if let placement = placement {
                adUnit.videoParameters.placement = placement
            }
            adConfiguration = adUnit.adUnitConfig.adConfiguration
        }
        
        let sdkConfiguration = Prebid.mock
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        let bidRequest = PBMORTBBidRequest()
        builder.build(bidRequest)
        
        guard let video = bidRequest.imp.first?.video else {
            XCTFail("No video object!")
            return
        }
        
        if (expectedPlacement == 0) {
            XCTAssertNil(video.placement)
        } else {
            PBMAssertEq(video.placement?.intValue, expectedPlacement)
        }
    }
    
    func testParameterBuilderDeprecatedProperties() {
        
        //Create Builder
        let adConfiguration = AdConfiguration()
        
        targeting.addParam("rab", withName: "foo")
        adConfiguration.isInterstitialAd = false
        
        let sdkConfiguration = Prebid.mock
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        
        //Run Builder
        let bidRequest = PBMORTBBidRequest()
        builder.build(bidRequest)
        
        //Check Regs
        XCTAssertNil(bidRequest.regs.coppa)
    }
    
    // MARK: - Helpers
    
    func checkDefaultParametersForAdUnit(adConfiguration: AdConfiguration) {
        let sdkConfiguration = Prebid.mock
        
        let builder = PBMBasicParameterBuilder(adConfiguration:adConfiguration,
                                               sdkConfiguration:sdkConfiguration,
                                               sdkVersion:"MOCK_SDK_VERSION",
                                               targeting: targeting)
        
        let bidRequest = PBMORTBBidRequest()
        builder.build(bidRequest)
        
        //Check that this is counted as an interstitial
        PBMAssertEq(bidRequest.imp.count, 1)
        guard let imp = bidRequest.imp.first else {
            XCTFail("No Imp object!")
            return
        }
        
        PBMAssertEq(imp.instl, 1)
        
        // Multiformat is default for interstitial ad unit
        guard let banner = imp.banner else {
            XCTFail("No banner object!")
            return
        }
        
        guard let video = imp.video else {
            XCTFail("No video object!")
            return
        }
        
        // default values for banner object
        XCTAssertEqual(banner.api, nil)
        XCTAssertEqual(banner.format, [])
        
        // default values for video object
        XCTAssertEqual(video.mimes, PBMConstants.supportedVideoMimeTypes)
        XCTAssertEqual(video.protocols, [2, 5])
        XCTAssertEqual(video.playbackend, 2)
        XCTAssertEqual(video.delivery, [3])
        XCTAssertEqual(video.pos, 7)
        XCTAssertEqual(video.api, nil)
        XCTAssertEqual(video.linearity, 1)
    }
}
