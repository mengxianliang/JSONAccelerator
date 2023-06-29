//
//  OutputLanguageWriterSwift.m
//  JSON Accelerator
//
//  Created by mxl on 2023/6/21.
//  Copyright © 2023 Nerdery Interactive Labs. All rights reserved.
//

#import "OutputLanguageWriterSwift.h"
#import "ClassBaseObject.h"
#import "NSString+Nerdery.h"

#ifndef COMMAND_LINE
    #import <AddressBook/AddressBook.h>
#endif

@interface OutputLanguageWriterSwift ()

@property (nonatomic, assign) BOOL buildForARC;

- (NSString *)ObjC_HeaderFileForClassObject:(ClassBaseObject *)classObject;
- (NSString *)ObjC_ImplementationFileForClassObject:(ClassBaseObject *)classObject;
- (NSString *)processHeaderForString:(NSString *)unprocessedString;

@end

@implementation OutputLanguageWriterSwift

#pragma mark - File Writing Methods

- (BOOL)writeClassObjects:(NSDictionary *)classObjectsDict toURL:(NSURL *)url options:(NSDictionary *)options generatedError:(BOOL *)generatedErrorFlag {
    BOOL filesHaveHadError = NO;
    BOOL filesHaveBeenWritten = NO;
    
    NSArray *files = classObjectsDict.allValues;
    
    /* Determine whether or not to build for ARC */
    if (nil != options[kObjectiveCWritingOptionUseARC]) {
        self.buildForARC = [options[kObjectiveCWritingOptionUseARC] boolValue];
    } else {
        /* Default to not building for ARC */
        self.buildForARC = NO;
    }
    
    for (ClassBaseObject *base in files) {
        NSString *newBaseClassName = base.className;
        
        // This section is to guard against people going through and renaming the class
        // to something that has already been named.
        // This will check the class name and keep appending an additional number until something has been found
        
        if ([base.className isEqualToString:@"InternalBaseClass"]) {
            
            if (nil != options[kObjectiveCWritingOptionBaseClassName]) {
                newBaseClassName = options[kObjectiveCWritingOptionBaseClassName];
            } else {
                newBaseClassName = @"BaseClass";
            }
            
            BOOL hasUniqueFileNameBeenFound = NO;
            NSUInteger classCheckInteger = 2;
            
            while (hasUniqueFileNameBeenFound == NO) {
                hasUniqueFileNameBeenFound = YES;
                
                for (ClassBaseObject *collisionBaseObject in files) {
                    if ([collisionBaseObject.className isEqualToString:newBaseClassName]) {
                        hasUniqueFileNameBeenFound = NO;
                    }
                }
                
                if (hasUniqueFileNameBeenFound == NO) {
                    newBaseClassName = [NSString stringWithFormat:@"%@%li", newBaseClassName, classCheckInteger];
                    classCheckInteger++;
                }
            }
        }
        
        if (nil != options[kObjectiveCWritingOptionClassPrefix]) {
            newBaseClassName = [NSString stringWithFormat:@"%@%@", options[kObjectiveCWritingOptionClassPrefix], newBaseClassName ];
        }
        
        base.className = newBaseClassName;
    }
    
    for (ClassBaseObject *base in files) {
        /* Write the h file to disk */
        NSError *hFileError;
        NSString *outputHFile = [self ObjC_HeaderFileForClassObject:base];
        NSString *hFilename = [NSString stringWithFormat:@"%@Model.swift", base.className];
        
#ifndef COMMAND_LINE
        [outputHFile writeToURL:[url URLByAppendingPathComponent:hFilename]
                      atomically:YES
                        encoding:NSUTF8StringEncoding
                           error:&hFileError];
#else
        [outputHFile writeToFile:[[url URLByAppendingPathComponent:hFilename] absoluteString]
                      atomically:YES
                        encoding:NSUTF8StringEncoding
                           error:&hFileError];
#endif
        
        if (hFileError) {
            DLog(@"%@", [hFileError localizedDescription]);
            filesHaveHadError = YES;
        } else {
            filesHaveBeenWritten = YES;
        }
    }
    
    /* Return the error flag (by reference) */
    *generatedErrorFlag = filesHaveHadError;
    
    
    return filesHaveBeenWritten;
}

- (NSString *)ObjC_HeaderFileForClassObject:(ClassBaseObject *)classObject {
#ifndef COMMAND_LINE
    NSBundle *mainBundle = [NSBundle mainBundle];
    
    NSString *interfaceTemplate = [mainBundle pathForResource:@"SwiftTemplate" ofType:@"txt"];
    NSString *templateString = [[NSString alloc] initWithContentsOfFile:interfaceTemplate encoding:NSUTF8StringEncoding error:nil];
#else
    /// swift
    NSString *templateString =  @"//\n//  {CLASSNAME}.h\n//\n//  Created by __NAME__ on {DATE}\n//  Copyright (c) {COMPANY_NAME}. All rights reserved.\n//\n\nimport SwiftyJSON\n\n{FORWARD_DECLARATION}\n\nclass {CLASSNAME} : {BASEOBJECT} {\n\n{PROPERTIES}\n+ ({CLASSNAME} *)modelObjectWithDictionary:(NSDictionary *)dict;\n- (instancetype)initWithDictionary:(NSDictionary *)dict;\n- (NSDictionary *)dictionaryRepresentation;\n\n}\n";
#endif
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{CLASSNAME}" withString:classObject.className];
    
    /* Set the date */
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{DATE}" withString:[dateFormatter stringFromDate:currentDate]];
    
    templateString = [self processHeaderForString:templateString];
    
    // First we need to find if there are any class properties, if so do the @Class business
    NSString *forwardDeclarationString = @"";
    
    for (ClassPropertiesObject *property in (classObject.properties).allValues) {
        if (property.isClass) {
            if ([forwardDeclarationString isEqualToString:@""]) {
                forwardDeclarationString = [NSString stringWithFormat:@"@class %@", property.referenceClass.className];
            } else {
                forwardDeclarationString = [forwardDeclarationString stringByAppendingFormat:@", %@", property.referenceClass.className];
            }
        }
    }
    
    if ([forwardDeclarationString isEqualToString:@""] == NO) {
        forwardDeclarationString = [forwardDeclarationString stringByAppendingString:@";"];
    }
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{FORWARD_DECLARATION}" withString:forwardDeclarationString];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{BASEOBJECT}" withString:classObject.baseClass];
    
    NSString *propertyString = @"";
    
    for (ClassPropertiesObject *property in (classObject.properties).allValues) {
        
        propertyString = [propertyString stringByAppendingFormat:@"%@\n", [self propertyForProperty:property]];
    }
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{PROPERTIES}" withString:propertyString];
    
    NSString *setterString = @"";
    
    for (ClassPropertiesObject *property in (classObject.properties).allValues) {
        
        setterString = [setterString stringByAppendingFormat:@"%@\n", [self setterForProperty:property]];
    }
    
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{INITWITHJSON}" withString:setterString];
    
    return templateString;
}

- (NSString *)processHeaderForString:(NSString *)unprocessedString {
    NSString *templateString = [unprocessedString copy];
    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    
    /* Set the name and company values in the template from the current logged in user's address book information */
#ifndef COMMAND_LINE
    ABAddressBook *addressBook = [ABAddressBook sharedAddressBook];
    ABPerson *me = [addressBook me];
    NSString *meFirstName = [me valueForProperty:kABFirstNameProperty];
    NSString *meLastName = [me valueForProperty:kABLastNameProperty];
    NSString *meCompany = [me valueForProperty:kABOrganizationProperty];
#else
    NSString *meFirstName = @"";
    NSString *meLastName = @"";
    NSString *meCompany = @"";
#endif
    
    if (meFirstName == nil) {
        meFirstName = @"";
    }
    
    if (meLastName == nil) {
        meLastName = @"";
    }
    
    if (meCompany == nil) {
        meCompany = @"__MyCompanyName__";
    }

    templateString = [templateString stringByReplacingOccurrencesOfString:@"__NAME__" withString:[NSString stringWithFormat:@"%@ %@", meFirstName, meLastName]];
    
    NSString *companyReplacement = [NSString stringWithFormat:@"%@ %@", [currentDate descriptionWithCalendarFormat:@"%Y" timeZone:nil locale:nil], meCompany];
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{COMPANY_NAME}"
                                                               withString:companyReplacement];
    
    /* Set other template strings */
    templateString = [templateString stringByReplacingOccurrencesOfString:@"{DATE}"
                                                               withString:[dateFormatter stringFromDate:currentDate]];
    
    return templateString;
}

#pragma mark - Reserved Words Callbacks

- (NSSet *)reservedWords {
    return [NSSet setWithObjects:@"associatedtype", @"class", @"deinit",
        @"enum", @"extension", @"fileprivate",
        @"func", @"import", @"init",
        @"inout", @"internal", @"let",
        @"open", @"operator", @"private",
        @"protocol", @"public", @"rethrows",
        @"static", @"struct", @"subscript",
        @"typealias", @"var",
        @"break", @"case", @"continue",
        @"default", @"defer", @"do",
        @"else", @"fallthrough", @"for",
        @"guard", @"if", @"in",
        @"repeat", @"return", @"switch",
        @"where", @"while",
        @"as", @"Any", @"catch",
        @"false", @"is", @"nil",
        @"super", @"self", @"Self",
        @"throw", @"throws", @"true",
        @"try", nil];
}

- (NSString *)dictionaryRepresentationfromProperty:(ClassPropertiesObject *)property {
    // Arrays are another bag of tricks
    if (property.type == PropertyTypeArray) {
#ifndef COMMAND_LINE
        NSBundle *mainBundle = [NSBundle mainBundle];
        
        NSString *implementationTemplate = [mainBundle pathForResource:@"DictionaryRepresentationArrayTemplate" ofType:@"txt"];
        NSString *templateString = [[NSString alloc] initWithContentsOfFile:implementationTemplate encoding:NSUTF8StringEncoding error:nil];
#else
        NSString *templateString = @"NSMutableArray *tempArrayFor{ARRAY_GETTER_NAME} = [NSMutableArray array];\n    for (NSObject *subArrayObject in self.{ARRAY_GETTER_NAME_LOWERCASE}) {\n        if ([subArrayObject respondsToSelector:@selector(dictionaryRepresentation)]) {\n            // This class is a model object\n            [tempArrayFor{ARRAY_GETTER_NAME} addObject:[subArrayObject performSelector:@selector(dictionaryRepresentation)]];\n        } else {\n            // Generic object\n            [tempArrayFor{ARRAY_GETTER_NAME} addObject:subArrayObject];\n        }\n    }\n    [mutableDict setValue:[NSArray arrayWithArray:tempArrayFor{ARRAY_GETTER_NAME}] forKey:%@];\n";
#endif
        templateString = [templateString stringByReplacingOccurrencesOfString:@"{ARRAY_GETTER_NAME}" withString:[property.name uppercaseCamelcaseString]];
        templateString = [templateString stringByReplacingOccurrencesOfString:@"{ARRAY_GETTER_NAME_LOWERCASE}" withString:[property.name lowercaseCamelcaseString]];
        
        return [NSString stringWithFormat:templateString, [self stringConstantForProperty:property]];
    }

    
    NSString *dictionaryRepresentation = @"";
    NSString *formatString = @"    [mutableDict setValue:%@ forKey:%@];\n";
    NSString *value;
    NSString *key = [NSString stringWithFormat:@"%@", [self stringConstantForProperty:property]];
    
    switch (property.type) {
        case PropertyTypeString:
        case PropertyTypeDictionary:
        case PropertyTypeOther:
            value = [NSString stringWithFormat:@"self.%@", [property.name lowercaseCamelcaseString]];
            break;
        case PropertyTypeClass:
            value = [NSString stringWithFormat:@"[self.%@ dictionaryRepresentation]", [property.name lowercaseCamelcaseString]];
            break;

        case PropertyTypeInt:
            value = [NSString stringWithFormat:@"[NSNumber numberWithInt:self.%@]", [property.name lowercaseCamelcaseString]];
            break;
        case PropertyTypeBool:
            value = [NSString stringWithFormat:@"[NSNumber numberWithBool:self.%@]", [property.name lowercaseCamelcaseString]];
            break;
        case PropertyTypeDouble:
            value = [NSString stringWithFormat:@"[NSNumber numberWithDouble:self.%@]", [property.name lowercaseCamelcaseString]];
            break;
        case PropertyTypeArray:
            NSAssert(NO, @"This shouldn't happen");
            break;
            
    }
    dictionaryRepresentation = [NSString stringWithFormat:formatString, value, key];
    
    return dictionaryRepresentation;
}

- (NSString *)classNameForObject:(ClassBaseObject *)classObject fromReservedWord:(NSString *)reservedWord {
    NSString *className = [[reservedWord stringByAppendingString:@"Class"] capitalizeFirstCharacter];
    NSRange startsWithNumeral = [[className substringToIndex:1] rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
    
    if ( !(startsWithNumeral.location == NSNotFound && startsWithNumeral.length == 0) ) {
        className = [@"Num" stringByAppendingString:className];
    }
    
    return className;
}

- (NSString *)propertyNameForObject:(ClassPropertiesObject *)propertyObject inClass:(ClassBaseObject *)classObject fromReservedWord:(NSString *)reservedWord {
    /* Special cases */
    if ([reservedWord isEqualToString:@"id"]) {
        return [[classObject.className stringByAppendingString:@"Identifier"] uncapitalizeFirstCharacter];
    } else if ([reservedWord isEqualToString:@"description"]) {
        return [[classObject.className stringByAppendingString:@"Description"] uncapitalizeFirstCharacter];
    } else if ([reservedWord isEqualToString:@"self"]) {
        return [[classObject.className stringByAppendingString:@"Self"] uncapitalizeFirstCharacter];
    }
    
    /* General case */
    NSString *propertyName = [[reservedWord stringByAppendingString:@"Property"] uncapitalizeFirstCharacter];
    NSRange startsWithNumeral = [[propertyName substringToIndex:1] rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]];
    
    if ( !(startsWithNumeral.location == NSNotFound && startsWithNumeral.length == 0) ) {
        propertyName = [@"num" stringByAppendingString:propertyName];
    }
    
    return [propertyName uncapitalizeFirstCharacter];
}

#pragma mark - Property Writing Methods

- (NSString *)propertyForProperty:(ClassPropertiesObject *)property {
    
    NSString *returnString = @"    var ";
    returnString = [returnString stringByAppendingFormat:@"%@: %@", property.name, [self typeStringForProperty:property]];
    
    return returnString;
}

- (NSString *)setterForProperty:(ClassPropertiesObject *)property {
    
    NSString *returnString = @"        ";
    returnString = [returnString stringByAppendingFormat:@"%@ = %@", property.name, [self jsonStringForProperty:property]];
   
    return returnString;
}

- (NSString *)typeStringForProperty:(ClassPropertiesObject *)property {
    switch (property.type) {
        case PropertyTypeString:
            return @"String";
            break;
        case PropertyTypeArray:
            return [NSString stringWithFormat:@"[%@]",property.referenceClass.className];
            break;
        case PropertyTypeDictionary:
            return @"Dictionary";
            break;
        case PropertyTypeInt:
            return @"Int";
            break;
        case PropertyTypeBool:
            return @"Bool";
            break;
        case PropertyTypeDouble:
            return @"Float";
            break;
        case PropertyTypeClass:
            return property.referenceClass.className;
            break;
        case PropertyTypeOther:
            return @"String";
            break;
            
        default:
            break;
    }
}

- (NSString *)jsonStringForProperty:(ClassPropertiesObject *)property {
    
    NSString *jsonString = @"";
    
    switch (property.type) {
        case PropertyTypeString:
            jsonString = [NSString stringWithFormat:@"json[\"%@\"].stringValue", property.name];
            break;
        case PropertyTypeInt:
            jsonString = [NSString stringWithFormat:@"json[\"%@\"].intValue", property.name];
            break;
        case PropertyTypeDouble:
            jsonString = [NSString stringWithFormat:@"json[\"%@\"].floatValue", property.name];
            break;
        case PropertyTypeBool:
            jsonString = [NSString stringWithFormat:@"json[\"%@\"].boolValue", property.name];
            break;
        case PropertyTypeArray:
            jsonString = [NSString stringWithFormat:@"json[\"%@\"].arrayValue.compactMap { %@(json: $0) }", property.name, property.referenceClass.className];
            break;
        case PropertyTypeClass:
            jsonString = [NSString stringWithFormat:@"%@(json: json[\"%@\"])", property.referenceClass.className, property.name];
            break;
            
        default:
            jsonString = [NSString stringWithFormat:@"json[\"%@\"].stringValue", property.name];
            break;
    }
    return jsonString;
}

- (NSString *)stringConstantForProperty:(ClassPropertiesObject *)property {
    return [NSString stringWithFormat:@"k{CLASSNAME}%@", [property.jsonName uppercaseCamelcaseString]];
}

@end
