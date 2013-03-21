//
//  RZFilteredCollectionListTests.m
//  RZCollectionList-Demo
//
//  Created by Joe Goullaud on 3/19/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZFilteredCollectionListTests.h"
#import "ListItemObject.h"
#import "RZArrayCollectionList.h"
#import "RZFilteredCollectionList.h"

typedef void (^RZCollectionListTestObserverWillChangeBlock)(id<RZCollectionList> collectionList);
typedef void (^RZCollectionListTestObserverDidChangeBlock)(id<RZCollectionList> collectionList);
typedef void (^RZCollectionListTestObserverDidChangeSectionBlock)(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type);
typedef void (^RZCollectionListTestObserverDidChangeObjectBlock)(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath);

@interface RZFilteredCollectionListTests () <RZCollectionListObserver>

@property (nonatomic, copy) RZCollectionListTestObserverWillChangeBlock willChangeBlock;
@property (nonatomic, copy) RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock;
@property (nonatomic, copy) RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock;
@property (nonatomic, copy) RZCollectionListTestObserverDidChangeBlock didChangeBlock;



- (NSArray*)listItemObjects;

- (void)logCollectionList:(id<RZCollectionList>)collectionList;

@end

@implementation RZFilteredCollectionListTests

- (NSArray*)listItemObjects
{
    NSUInteger numItems = 10;
    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:numItems];
    
    for (int i=0; i < numItems; ++i)
    {
        NSString *itemName = [NSString stringWithFormat:@"Item %d", i];
        NSString *itemSubtitle = [NSString stringWithFormat:@"%d Subtitle", i / 3];
        [items addObject:[ListItemObject listItemObjectWithName:itemName subtitle:itemSubtitle]];
    }
    
    return items;
}

- (void)logCollectionList:(id<RZCollectionList>)collectionList
{
    [[collectionList sections] enumerateObjectsUsingBlock:^(id<RZCollectionListSectionInfo> section, NSUInteger sectionIndex, BOOL *stop) {
        NSLog(@"Section %u - %@ Count: %u", sectionIndex, [section name], [section numberOfObjects]);
        
        [[section objects] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSLog(@"  %u:%@", idx, [obj description]);
        }];
    }];
}

- (void)setUp
{
    [super setUp];
    
    self.arrayList = [[RZArrayCollectionList alloc] initWithArray:[self listItemObjects] sectionNameKeyPath:@"subtitle"];
    self.filteredList = [[RZFilteredCollectionList alloc] initWithSourceList:self.arrayList predicate:nil];
    
    [self.filteredList addCollectionListObserver:self];
}

- (void)tearDown
{
    [self.filteredList removeCollectionListObserver:self];
    self.filteredList = nil;
    self.arrayList = nil;
    
    [super tearDown];
}

- (void)test01MoveShownObjectWithinSectionChangingFilteredOrder
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (1 == [evaluatedObject.subtitle intValue]%2);
    }];
    
    __block BOOL willChangeCalled = NO;
    __block BOOL didChangeObjectCalled = NO;
    __block BOOL didChangeCalled = NO;
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertFalse(willChangeCalled, @"Will Change has already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        willChangeCalled = YES;
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STFail(@"Did Change Section was called when it shouldn't be.");
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        STAssertTrue(type == RZCollectionListChangeMove, @"Object Change Type is not Move.");
        STAssertEqualObjects(indexPath, [NSIndexPath indexPathForRow:0 inSection:0], @"Incorrect fromIndexPath. Expected 0:0");
        STAssertEqualObjects(newIndexPath, [NSIndexPath indexPathForRow:1 inSection:0], @"Incorrect toIndexPath. Expected 0:1");
        didChangeObjectCalled = YES;
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertTrue(didChangeObjectCalled, @"Did Change Object should have already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        didChangeCalled = YES;
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:0 inSection:1];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:1 inSection:1];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    STAssertTrue(willChangeCalled, @"Will Change should have been called.");
    STAssertTrue(didChangeObjectCalled, @"Did Change Object should have been called.");
    STAssertTrue(didChangeCalled, @"Did Change should have been called.");
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

- (void)test02MoveShownObjectWithinSectionNoFilteredOrderChange
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (1 == [[evaluatedObject.itemName stringByReplacingOccurrencesOfString:@"Item" withString:@""] intValue]%2);
    }];
    
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Will Change was called when it shouldn't be.");
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STFail(@"Did Change Section was called when it shouldn't be.");
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STFail(@"Did Change Object was called when it shouldn't be.");
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Did Change was called when it shouldn't be.");
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:0 inSection:1];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:1 inSection:1];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

- (void)test03MoveShownObjectBetweenSections
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (1 == [[evaluatedObject.itemName stringByReplacingOccurrencesOfString:@"Item" withString:@""] intValue]%2);
    }];
    
    __block BOOL willChangeCalled = NO;
    __block BOOL didChangeObjectCalled = NO;
    __block BOOL didChangeCalled = NO;
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertFalse(willChangeCalled, @"Will Change has already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        willChangeCalled = YES;
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STFail(@"Did Change Section was called when it shouldn't be.");
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        STAssertTrue(type == RZCollectionListChangeMove, @"Object Change Type is not Move.");
        STAssertEqualObjects(indexPath, [NSIndexPath indexPathForRow:0 inSection:1], @"Incorrect fromIndexPath. Expected 1:0");
        STAssertEqualObjects(newIndexPath, [NSIndexPath indexPathForRow:0 inSection:0], @"Incorrect toIndexPath. Expected 0:0");
        didChangeObjectCalled = YES;
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertTrue(didChangeObjectCalled, @"Did Change Object should have already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        didChangeCalled = YES;
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:0 inSection:1];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

- (void)test04MoveLastShownObjectInSectionBetweenSections
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (1 == [[evaluatedObject.itemName stringByReplacingOccurrencesOfString:@"Item" withString:@""] intValue]%2);
    }];
    
    __block BOOL willChangeCalled = NO;
    __block BOOL didChangeSectionCalled = NO;
    __block BOOL didChangeObjectCalled = NO;
    __block BOOL didChangeCalled = NO;
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertFalse(willChangeCalled, @"Will Change has already been called.");
        STAssertFalse(didChangeSectionCalled, @"Did Change Section has already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        willChangeCalled = YES;
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertFalse(didChangeSectionCalled, @"Did Change Section has already been called.");
        STAssertTrue(didChangeObjectCalled, @"Did Change Object should have already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        STAssertTrue(type == RZCollectionListChangeDelete, @"Section Change Type is not Delete.");
        STAssertTrue(sectionIndex == 0, @"Section Index to remove is not 0");
        didChangeSectionCalled = YES;
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertFalse(didChangeSectionCalled, @"Did Change Section has already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        STAssertTrue(type == RZCollectionListChangeMove, @"Object Change Type is not Move.");
        STAssertEqualObjects(indexPath, [NSIndexPath indexPathForRow:0 inSection:0], @"Incorrect fromIndexPath. Expected 0:0");
        STAssertEqualObjects(newIndexPath, [NSIndexPath indexPathForRow:1 inSection:1], @"Incorrect toIndexPath. Expected 1:1");
        didChangeObjectCalled = YES;
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertTrue(didChangeSectionCalled, @"Did Change Section should have already been called.");
        STAssertTrue(didChangeObjectCalled, @"Did Change Object should have already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        didChangeCalled = YES;
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:1 inSection:0];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:1 inSection:1];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

- (void)test05MoveShownObjectBetweenSectionsIntoEmptySection
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (1 == [evaluatedObject.subtitle intValue]%2);
    }];
    
    __block BOOL willChangeCalled = NO;
    __block BOOL didChangeSectionCalled = NO;
    __block BOOL didChangeObjectCalled = NO;
    __block BOOL didChangeCalled = NO;
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertFalse(willChangeCalled, @"Will Change has already been called.");
        STAssertFalse(didChangeSectionCalled, @"Did Change Section has already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        willChangeCalled = YES;
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertFalse(didChangeSectionCalled, @"Did Change Section has already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        STAssertTrue(type == RZCollectionListChangeInsert, @"Section Change Type is not Insert.");
        STAssertTrue(sectionIndex == 0, @"Section Index to add is not 0");
        didChangeSectionCalled = YES;
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertTrue(didChangeSectionCalled, @"Did Change Section should have already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        STAssertTrue(type == RZCollectionListChangeMove, @"Object Change Type is not Move.");
        STAssertEqualObjects(indexPath, [NSIndexPath indexPathForRow:0 inSection:1], @"Incorrect fromIndexPath. Expected 1:0");
        STAssertEqualObjects(newIndexPath, [NSIndexPath indexPathForRow:0 inSection:0], @"Incorrect toIndexPath. Expected 0:0");
        didChangeObjectCalled = YES;
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertTrue(didChangeSectionCalled, @"Did Change Section should have already been called.");
        STAssertTrue(didChangeObjectCalled, @"Did Change Object should have already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        didChangeCalled = YES;
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:0 inSection:1];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

- (void)test06MoveLastShownObjectInSectionIntoEmptySection
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (1 == [evaluatedObject.subtitle intValue]%2);
    }];
    
    __block BOOL willChangeCalled = NO;
    __block BOOL didChangeSectionCalled = NO;
    __block BOOL didChangeObjectCalled = NO;
    __block BOOL didChangeCalled = NO;
    __block NSUInteger didChangeSectionCallCount = 0;
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertFalse(willChangeCalled, @"Will Change has already been called.");
        STAssertFalse(didChangeSectionCalled, @"Did Change Section has already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        willChangeCalled = YES;
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        
        switch (type) {
            case RZCollectionListChangeInsert:
                STAssertFalse(didChangeSectionCalled, @"Did Change Section has already been called.");
                STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
                STAssertTrue(sectionIndex == 0, @"Section Index to add is not 0");
                break;
            case RZCollectionListChangeDelete:
                STAssertTrue(didChangeSectionCalled, @"Did Change Section should have already been called.");
                STAssertTrue(didChangeSectionCallCount == 1, @"Did Change Section Call Count should be 1.");
                STAssertTrue(didChangeObjectCalled, @"Did Change Object should have already been called.");
                STAssertTrue(sectionIndex == 2, @"Section Index to remove is not 2");
                
                break;
            default:
                STFail(@"Section Change Type is not Insert or Delete.");
                break;
        }
        
        didChangeSectionCalled = YES;
        ++didChangeSectionCallCount;
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertTrue(didChangeSectionCalled, @"Did Change Section should have already been called.");
        STAssertFalse(didChangeObjectCalled, @"Did Change Object has already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        STAssertTrue(type == RZCollectionListChangeMove, @"Object Change Type is not Move.");
        STAssertEqualObjects(indexPath, [NSIndexPath indexPathForRow:0 inSection:2], @"Incorrect fromIndexPath. Expected 1:0");
        STAssertEqualObjects(newIndexPath, [NSIndexPath indexPathForRow:0 inSection:0], @"Incorrect toIndexPath. Expected 0:0");
        didChangeObjectCalled = YES;
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STAssertTrue(willChangeCalled, @"Will Change should have already been called.");
        STAssertTrue(didChangeSectionCalled, @"Did Change Section should have already been called.");
        STAssertTrue(didChangeSectionCallCount == 2, @"Did Change Section Call Count should be 2.");
        STAssertTrue(didChangeObjectCalled, @"Did Change Object should have already been called.");
        STAssertFalse(didChangeCalled, @"Did Change has already been called.");
        didChangeCalled = YES;
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:0 inSection:3];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

#pragma mark - Moving Filtered Objects

- (void)test07MoveHiddenObjectWithinSection
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (1 == [evaluatedObject.subtitle intValue]%2);
    }];
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Will Change was called when it shouldn't be.");
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STFail(@"Did Change Section was called when it shouldn't be.");
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STFail(@"Did Change Object was called when it shouldn't be.");
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Did Change was called when it shouldn't be.");
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:1 inSection:0];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

- (void)test08MoveHiddenObjectBetweenVisibleSections
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (1 == [[evaluatedObject.itemName stringByReplacingOccurrencesOfString:@"Item" withString:@""] intValue]%2);
    }];
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Will Change was called when it shouldn't be.");
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STFail(@"Did Change Section was called when it shouldn't be.");
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STFail(@"Did Change Object was called when it shouldn't be.");
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Did Change was called when it shouldn't be.");
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:0 inSection:1];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

- (void)test09MoveHiddenLastObjectInSectionBetweenSections
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (0 == [[evaluatedObject.itemName stringByReplacingOccurrencesOfString:@"Item" withString:@""] intValue]%2);
    }];
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Will Change was called when it shouldn't be.");
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STFail(@"Did Change Section was called when it shouldn't be.");
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STFail(@"Did Change Object was called when it shouldn't be.");
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Did Change was called when it shouldn't be.");
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:1 inSection:3];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

- (void)test10MoveHiddenObjectBetweenSectionsIntoEmptySection
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (1 == [evaluatedObject.subtitle intValue]%2);
    }];
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Will Change was called when it shouldn't be.");
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STFail(@"Did Change Section was called when it shouldn't be.");
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STFail(@"Did Change Object was called when it shouldn't be.");
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Did Change was called when it shouldn't be.");
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:0 inSection:2];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

- (void)test11MoveHiddenLastObjectInSectionIntoEmptySection
{
    self.filteredList.predicate = [NSPredicate predicateWithBlock:^BOOL(ListItemObject *evaluatedObject, NSDictionary *bindings) {
        return (0 == [evaluatedObject.subtitle intValue]%2);
    }];
    
    RZCollectionListTestObserverWillChangeBlock willChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Will Change was called when it shouldn't be.");
    };
    
    self.willChangeBlock = willChangeBlock;
    
    RZCollectionListTestObserverDidChangeSectionBlock didChangeSectionBlock = ^(id<RZCollectionList> collectionList, id<RZCollectionListSectionInfo> sectionInfo, NSUInteger sectionIndex, RZCollectionListChangeType type){
        STFail(@"Did Change Section was called when it shouldn't be.");
    };
    
    self.didChangeSectionBlock = didChangeSectionBlock;
    
    RZCollectionListTestObserverDidChangeObjectBlock didChangeObjectBlock = ^(id<RZCollectionList> collectionList, id object, NSIndexPath *indexPath, RZCollectionListChangeType type, NSIndexPath *newIndexPath){
        STFail(@"Did Change Object was called when it shouldn't be.");
    };
    
    self.didChangeObjectBlock = didChangeObjectBlock;
    
    RZCollectionListTestObserverDidChangeBlock didChangeBlock = ^(id<RZCollectionList> collectionList){
        STFail(@"Did Change was called when it shouldn't be.");
    };
    
    self.didChangeBlock = didChangeBlock;
    
    NSLog(@"Start Filtered Array:\n");
    [self logCollectionList:self.filteredList];
    
    NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:0 inSection:3];
    NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:0 inSection:1];
    
    [self.arrayList moveObjectAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    
    NSLog(@"End Filtered Array:\n");
    [self logCollectionList:self.filteredList];
}

#pragma mark - RZCollectionListObserver

- (void)collectionListWillChangeContent:(id<RZCollectionList>)collectionList
{
#if 0
    NSLog(@"Received Will Change Notification");
#endif
    
    if (self.willChangeBlock)
    {
        self.willChangeBlock(collectionList);
    }
}

- (void)collectionList:(id<RZCollectionList>)collectionList didChangeSection:(id<RZCollectionListSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(RZCollectionListChangeType)type
{
#if 0
    NSLog(@"Received Did Change Section Notification - Section %u Type %u", sectionIndex, type);
#endif
    
    if (self.didChangeSectionBlock)
    {
        self.didChangeSectionBlock(collectionList, sectionInfo, sectionIndex, type);
    }
}

- (void)collectionList:(id<RZCollectionList>)collectionList didChangeObject:(id)object atIndexPath:(NSIndexPath *)indexPath forChangeType:(RZCollectionListChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
#if 0
    NSLog(@"Received Did Change Object Notification - IndexPath %@ NewIndexPath:%@ Type %u Object %@", indexPath, newIndexPath, type, object);
#endif
    
    if (self.didChangeObjectBlock)
    {
        self.didChangeObjectBlock(collectionList, object, indexPath, type, newIndexPath);
    }
}

- (void)collectionListDidChangeContent:(id<RZCollectionList>)collectionList
{
#if 0
    NSLog(@"Received Did Change Notification");
#endif
    
    if (self.didChangeBlock)
    {
        self.didChangeBlock(collectionList);
    }
}

@end
