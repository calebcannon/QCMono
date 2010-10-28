//
//  NoodleLineNumberScrollView.m
//  QCMono
//
//  Created by Caleb Cannon on 10/22/10.
//  Copyright 2010 Caleb Cannon. All rights reserved.
//

#import "NoodleLineNumberScrollView.h"
#import "NoodleLineNumberView.h"

@implementation NoodleLineNumberScrollView

- (void) awakeFromNib
{
	NoodleLineNumberView *lineNumberView = [[NoodleLineNumberView alloc] initWithScrollView:self orientation:NSVerticalRuler];
	[self setVerticalRulerView:lineNumberView];
	[self setHorizontalRulerView:nil];
	[lineNumberView setClientView:[self documentView]];	
	[self setHasHorizontalRuler:NO];
	[self setHasVerticalRuler:YES];
}

+ (void) setRulerViewClass:(Class)aClass
{
	// Do nothing
}

- (NSRulerView *) horizontalRulerView
{
	return nil;
}

+ (Class)rulerViewClass
{
	return [NoodleLineNumberView class];
}

- (BOOL) hasVerticalRuler
{
	return YES;
}

- (BOOL) hasHorizontalRuler
{
	return NO;
}

@end
