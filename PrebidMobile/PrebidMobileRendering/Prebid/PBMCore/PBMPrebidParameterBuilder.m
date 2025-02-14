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

#import "PBMPrebidParameterBuilder.h"

#import "PBMORTB.h"
#import "PBMUserAgentService.h"

#import "PBMAdViewManagerDelegate.h"
#import "PBMJsonCodable.h"

#import "PBMBidRequesterFactoryBlock.h"
#import "PBMWinNotifierBlock.h"

#import "PBMORTBAppContent.h"

#import "PrebidMobileSwiftHeaders.h"
#import <PrebidMobile/PrebidMobile-Swift.h>

@interface PBMPrebidParameterBuilder ()

@property (nonatomic, strong, nonnull, readonly) AdUnitConfig *adConfiguration;
@property (nonatomic, strong, nonnull, readonly) Prebid *sdkConfiguration;
@property (nonatomic, strong, nonnull, readonly) Targeting *targeting;
@property (nonatomic, strong, nonnull, readonly) PBMUserAgentService *userAgentService;

@end

@implementation PBMPrebidParameterBuilder

- (instancetype)initWithAdConfiguration:(AdUnitConfig *)adConfiguration
                       sdkConfiguration:(Prebid *)sdkConfiguration
                              targeting:(Targeting *)targeting
                       userAgentService:(PBMUserAgentService *)userAgentService
{
    if (!(self = [super init])) {
        return nil;
    }
    _adConfiguration = adConfiguration;
    _sdkConfiguration = sdkConfiguration;
    _targeting = targeting;
    _userAgentService = userAgentService;
    return self;
}

- (void)buildBidRequest:(nonnull PBMORTBBidRequest *)bidRequest {
    
    NSSet<AdFormat *> *adFormats = self.adConfiguration.adConfiguration.adFormats;
    BOOL const isHTML = ([adFormats containsObject:AdFormat.display]);
    BOOL const isInterstitial = self.adConfiguration.adConfiguration.isInterstitialAd;
    
    bidRequest.requestID = [NSUUID UUID].UUIDString;
    bidRequest.extPrebid.storedRequestID        = self.sdkConfiguration.prebidServerAccountId;
    bidRequest.extPrebid.storedAuctionResponse  = Prebid.shared.storedAuctionResponse;
    bidRequest.extPrebid.dataBidders            = self.targeting.accessControlList;
    bidRequest.extPrebid.storedBidResponses     = [Prebid.shared getStoredBidResponses];
    
    if (Prebid.shared.useCacheForReportingWithRenderingAPI) {
        PBMMutableJsonDictionary * const cache = [PBMMutableJsonDictionary new];
        cache[@"bids"] = [PBMMutableJsonDictionary new];
        cache[@"vastxml"] = [PBMMutableJsonDictionary new];
        bidRequest.extPrebid.cache = cache;
    }
    
    bidRequest.app.publisher.publisherID        = self.sdkConfiguration.prebidServerAccountId;
    bidRequest.app.ver          = [NSBundle mainBundle].infoDictionary[@"CFBundleShortVersionString"];
    bidRequest.device.pxratio   = @([UIScreen mainScreen].scale);
    bidRequest.source.tid       = [NSUUID UUID].UUIDString;
    bidRequest.device.ua        = [self.userAgentService getFullUserAgent];
    
    bidRequest.app.content = [self.adConfiguration getAppContent];
    bidRequest.user.ext[@"data"] = self.targeting.userDataDictionary;
    
    if (self.targeting.gdprConsentString && self.targeting.gdprConsentString.length > 0) {
        bidRequest.user.ext[@"consent"] = self.targeting.gdprConsentString;
    }

    PBMORTBSourceExtOMID *extSource = [PBMORTBSourceExtOMID new];
    if (Targeting.shared.omidPartnerName) {
        extSource.omidpn = Targeting.shared.omidPartnerName;
    }
    if (Targeting.shared.omidPartnerVersion) {
        extSource.omidpv = Targeting.shared.omidPartnerVersion;
    }

    bidRequest.source.extOMID = extSource;

    NSArray<PBMORTBFormat *> *formats = nil;
    const NSInteger formatsCount = (CGSizeEqualToSize(self.adConfiguration.adSize, CGSizeZero) ? 0 : 1) + self.adConfiguration.additionalSizes.count;
    
    if (formatsCount > 0) {
        NSMutableArray<PBMORTBFormat *> * const newFormats = [[NSMutableArray alloc] initWithCapacity:formatsCount];
        if (!CGSizeEqualToSize(self.adConfiguration.adSize, CGSizeZero)) {
            NSValue *value = [NSValue valueWithCGSize:self.adConfiguration.adSize];
            [newFormats addObject:[PBMPrebidParameterBuilder ortbFormatWithSize: value]];
        }
        for (NSValue *nextSize in self.adConfiguration.additionalSizes) {
            [newFormats addObject:[PBMPrebidParameterBuilder ortbFormatWithSize:nextSize]];
        }
        formats = newFormats;
    } else if (isInterstitial) {
        NSNumber * const w = bidRequest.device.w;
        NSNumber * const h = bidRequest.device.h;
        if (w && h) {
            PBMORTBFormat * const newFormat = [[PBMORTBFormat alloc] init];
            newFormat.w = w;
            newFormat.h = h;
            formats = @[newFormat];
        }
        if (self.adConfiguration.minSizePerc && isHTML) {
            const CGSize minSizePerc = self.adConfiguration.minSizePerc.CGSizeValue;
            PBMORTBDeviceExtPrebidInterstitial * const interstitial = bidRequest.device.extPrebid.interstitial;
            interstitial.minwidthperc = @(minSizePerc.width);
            interstitial.minheightperc = @(minSizePerc.height);
        }
    }
    
    NSArray<PBMORTBContentData *> *userData = [self.adConfiguration getUserData];
    if (userData) {
        bidRequest.user.data = userData;
    }
    
    PBMORTBAppExtPrebid * const appExtPrebid = bidRequest.app.extPrebid;
    appExtPrebid.data = self.targeting.contextDataDictionary;
    
    for (PBMORTBImp *nextImp in bidRequest.imp) {
        nextImp.impID = [NSUUID UUID].UUIDString;
        nextImp.extPrebid.storedRequestID = self.adConfiguration.configId;
        nextImp.extPrebid.storedAuctionResponse = Prebid.shared.storedAuctionResponse;
        nextImp.extPrebid.isRewardedInventory = self.adConfiguration.adConfiguration.isOptIn;
        nextImp.extContextData = self.adConfiguration.contextDataDictionary.mutableCopy;
        nextImp.extContextData[@"adslot"] = [self.adConfiguration getPbAdSlot];
        for (AdFormat* adFormat in adFormats) {
            if (adFormat == AdFormat.display) {
                PBMORTBBanner * const nextBanner = nextImp.banner;
                if (formats) {
                    nextBanner.format = formats;
                }
                
                BannerParameters *bannerParameters = self.adConfiguration.adConfiguration.bannerParameters;
                
                if (bannerParameters.api && bannerParameters.api.count > 0) {
                    nextBanner.api = bannerParameters.rawAPI;
                }
                
                if (self.adConfiguration.adPosition != AdPositionUndefined) {
                    nextBanner.pos = @(self.adConfiguration.adPosition);
                }
            } else if (adFormat == AdFormat.video) {
                PBMORTBVideo * const nextVideo = nextImp.video;
                
                if (formats.count) {
                    PBMORTBFormat * const primarySize = (PBMORTBFormat *)formats[0];
                    nextVideo.w = primarySize.w;
                    nextVideo.h = primarySize.h;
                }
                
                VideoParameters *videoParameters = self.adConfiguration.adConfiguration.videoParameters;
                                
                if (videoParameters.api && videoParameters.api.count > 0) {
                    nextVideo.api = videoParameters.rawAPI;
                }
                
                if (videoParameters.maxBitrate) {
                    nextVideo.maxbitrate = [NSNumber numberWithInteger:videoParameters.maxBitrate.value];
                }
                
                if (videoParameters.minBitrate) {
                    nextVideo.minbitrate = [NSNumber numberWithInteger:videoParameters.minBitrate.value];
                }
                
                if (videoParameters.maxDuration) {
                    nextVideo.maxduration = [NSNumber numberWithInteger:videoParameters.maxDuration.value];
                }
                
                if (videoParameters.minDuration) {
                    nextVideo.minduration = [NSNumber numberWithInteger:videoParameters.minDuration.value];
                }
                
                if (videoParameters.mimes && videoParameters.mimes.count > 0) {
                    nextVideo.mimes = videoParameters.mimes;
                }
                
                if (videoParameters.playbackMethod && videoParameters.playbackMethod.count > 0) {
                    nextVideo.playbackmethod = videoParameters.rawPlaybackMethod;
                }
                
                if (videoParameters.protocols && videoParameters.protocols.count > 0) {
                    nextVideo.protocols = videoParameters.rawProtocols;
                }
                
                if (videoParameters.startDelay) {
                    nextVideo.startdelay = [NSNumber numberWithInteger:videoParameters.startDelay.value];
                }
                
                if (videoParameters.placement) {
                    nextVideo.placement = [NSNumber numberWithInteger:videoParameters.placement.value];
                }
                
                if (videoParameters.linearity) {
                    nextVideo.linearity = [NSNumber numberWithInteger:videoParameters.linearity.value];
                }
                
                if (self.adConfiguration.adPosition != AdPositionUndefined) {
                    nextVideo.pos = @(self.adConfiguration.adPosition);
                }
            } else if (adFormat == AdFormat.native && adFormats.count == 1) {
                PBMORTBNative * const nextNative = nextImp.native;
                nextNative.request = [self.adConfiguration.nativeAdConfiguration.markupRequestObject toJsonStringWithError:nil];
                NSString * const ver = self.adConfiguration.nativeAdConfiguration.version;
                if (ver) {
                    nextNative.ver = ver;
                }
            }
        }
        if (isInterstitial) {
            nextImp.instl = @(1);
        }
        if (!appExtPrebid.source) {
            appExtPrebid.source = nextImp.displaymanager;
        }
        if (!appExtPrebid.version) {
            appExtPrebid.version = nextImp.displaymanagerver;
        }
    }
}

+ (PBMORTBFormat *)ortbFormatWithSize:(NSValue *)size {
    PBMORTBFormat * const format = [[PBMORTBFormat alloc] init];
    CGSize const cgSize = size.CGSizeValue;
    format.w = @(cgSize.width);
    format.h = @(cgSize.height);
    return format;
}

@end
