/*
 *  QCMonoMultiSyntaxColoredTextDocument.c
 *  QCMono
 *
 *  Created by Caleb Cannon on 10/30/10.
 *  Copyright 2010 Caleb Cannon. All rights reserved.
 *
 */

#include "QCMonoMultiSyntaxColoredTextDocument.h"


@implementation QCMonoMultiSyntaxColorTextDocument

- (IBAction) setSelectedCompilerName:(id)sender
{
	if ([sender isKindOfClass:[NSPopUpButton class]])
	{
		NSPopUpButton *button = sender;
		NSString *compilerName = [[button selectedItem] title];
		NSString *filename = [compilerName stringByAppendingPathExtension:@"plist"];
		[self setSyntaxDefinitionFilename:filename];
	}
}

@end