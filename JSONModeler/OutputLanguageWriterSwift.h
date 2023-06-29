//
//  OutputLanguageWriterSwift.h
//  JSON Accelerator
//
//  Created by mxl on 2023/6/21.
//  Copyright © 2023 Nerdery Interactive Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ClassPropertiesObject.h"
#import "OutputLanguageWriterProtocol.h"
#import "ClassBaseObject.h"
#import "OutputLanguageWriterObjectiveC.h"

///* Writing options keys for OutputLanguageWriterProtocol methods */
//static NSString * const kObjectiveCWritingOptionBaseClassName = @"kObjectiveCWritingOptionBaseClassName";
//static NSString * const kObjectiveCWritingOptionUseARC = @"kObjectiveCWritingOptionUseARC";
//static NSString * const kObjectiveCWritingOptionClassPrefix = @"kObjectiveCWritingOptionClassPrefix";

@interface OutputLanguageWriterSwift : NSObject <OutputLanguageWriterProtocol>

@end
