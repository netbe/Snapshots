//
//  ORTestsSuiteModels.m
//  SnapshotDiffs
//
//  Created by Orta on 6/15/14.
//  Copyright (c) 2014 Orta. All rights reserved.
//

#import "ORTestsSuiteModels.h"
#import "NSFileManager+RecursiveFind.h"

@implementation ORTestSuite

+ (ORTestSuite *)suiteFromString:(NSString *)line
{
    NSArray *components = [line componentsSeparatedByString:@"Test Suite '"];
    NSArray *endComponents = [line componentsSeparatedByString:@"' started at"];

    if (components.count == 2 && endComponents.count == 2) {
        ORTestSuite *suite = [[ORTestSuite alloc] init];
        suite.testCases = [NSMutableArray array];
        suite.name = [[components.lastObject componentsSeparatedByString:@"'"] firstObject];
        return suite;
    }

    return nil;
}

- (ORTestCase *)latestTestCase
{
    return self.testCases.lastObject;
}

- (BOOL)hasFailingTests
{
    for (ORTestCase *testCase in self.testCases) {
        if (testCase.hasFailingTests) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)hasNewSnapshots
{
    for (ORTestCase *testCase in self.testCases) {
        if (testCase.snapshots.count > 0) {
            return YES;
        }
    }
    return NO;
}


@end

@implementation ORTestCase

+ (ORTestCase *)caseFromString:(NSString *)line
{
    NSArray *components = [line componentsSeparatedByString:@"Test Case '-["];
    NSArray *endComponents = [line componentsSeparatedByString:@"]' started."];
    
    if (components.count == 2 && endComponents.count == 2) {
        ORTestCase *testCase = [[ORTestCase alloc] init];
        testCase.commands = [NSMutableArray array];
        testCase.snapshots = [NSMutableArray array];

        // Let's make it readable
        NSString *name = [[components.lastObject componentsSeparatedByString:@"'"] firstObject];
        name = [[name componentsSeparatedByString:@" "] lastObject];
        name = [[name componentsSeparatedByString:@"]"] firstObject];
        name = [name stringByReplacingOccurrencesOfString:@"_" withString:@" "];

        // We avoid hitting ends of words by addng the space, but that potentially misses the first one
        name = [@" " stringByAppendingString:name];
        name = [name stringByReplacingOccurrencesOfString:@" hasn t" withString:@" hasn't"];
        name = [name stringByReplacingOccurrencesOfString:@" isn t" withString:@" isn't"];
        name = [name stringByReplacingOccurrencesOfString:@" won t" withString:@" won't"];
        name = [name stringByReplacingOccurrencesOfString:@" don t" withString:@" don't"];
        name = [name stringByReplacingOccurrencesOfString:@" doesn t" withString:@" doesn't"];
        name = [name stringByReplacingOccurrencesOfString:@" shouldn t" withString:@" shouldn't"];
        name = [name stringByReplacingOccurrencesOfString:@" can t" withString:@" can't"];
        
        // So we take the 2nd char and move it to be the first
        NSString *firstCharacterCaps = [[name substringWithRange:NSMakeRange(1, 1)] uppercaseString];
        name = [name stringByReplacingCharactersInRange:NSMakeRange(0,2) withString:firstCharacterCaps];
        testCase.name = name;
        return testCase;
    }

    return nil;
}

- (void)addCommand:(ORKaleidoscopeCommand *)command
{
    [self.commands addObject:command];
    command.testCase = self;
}

- (void)addSnapshot:(ORSnapshotCreationReference *)snapshot
{
    [self.snapshots addObject:snapshot];
    snapshot.testCase = self;
}

- (BOOL)hasFailingTests
{
    return self.uniqueDiffCommands.count > 0;
}

- (NSArray *)uniqueDiffCommands
{
    return [NSOrderedSet orderedSetWithArray: [self.commands filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(ORKaleidoscopeCommand *command, NSDictionary *bindings) {
        return [[NSFileManager defaultManager] contentsEqualAtPath:command.afterPath andPath:command.beforePath] == NO;
    }]]].array;
}


@end

@implementation ORKaleidoscopeCommand

+ (instancetype)commandFromString:(NSString *)command
{
    NSArray *components = [command componentsSeparatedByString:@"\""];
    if(components.count > 4){
        ORKaleidoscopeCommand *obj = [[self alloc] init];
        obj.fullCommand = command;
        obj.beforePath = components[1];
        obj.afterPath = components[3];
        return obj;
    }
    return nil;
}

- (BOOL)isEqual:(ORKaleidoscopeCommand *)anObject
{
    return [self.beforePath isEqual:anObject.beforePath] && [self.afterPath isEqual:anObject.afterPath];
}

- (NSUInteger)hash
{
    return [self.beforePath stringByAppendingString:self.afterPath].hash;
}

- (void)launch
{
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/local/bin/ksdiff"];

    NSArray *arguments = @[ self.beforePath, self.afterPath];
    [task setArguments: arguments];
    [task launch];
}

@end


@implementation ORSnapshotCreationReference

+ (instancetype)referenceFromString:(NSString *)line
{
    // 2014-06-16 11:34:57.579 ArtsyFolio[45418:60b] /Users/orta/dev/ios/energy/ArtsyFolio Tests/ARAdminPartnerSelectViewControllerTests.m:40 snapshot looks_right_on_phone successfully recorded, replace recordSnapshot with a check
    
    NSArray *components = [line componentsSeparatedByString:@"snapshot "];
    NSArray *endComponents = [line componentsSeparatedByString:@" successfully recorded, replace recordSnapshot with a check"];
    
    if (components.count == 2 && endComponents.count == 2) {

        ORSnapshotCreationReference *obj = [[self alloc] init];
        obj.name = [[endComponents.firstObject componentsSeparatedByString:@"snapshot"].lastObject stringByReplacingOccurrencesOfString:@" " withString:@""];
        return obj;
    }
    return nil;
}


- (BOOL)isEqual:(ORSnapshotCreationReference *)anObject
{
    return [self.path isEqual:anObject.path];
}

- (NSUInteger)hash
{
    return self.path.hash;
}


@end