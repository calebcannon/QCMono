//
//  QCMonoPlugIn.h
//  QCMono
//
//  Created by Caleb Cannon on 10/19/10.
//  Copyright (c) 2010 Caleb Cannon. All rights reserved.
//

#import <Quartz/Quartz.h>

#include <mono/jit/jit.h>
#include <mono/metadata/assembly.h>
#include <mono/metadata/mono-config.h>
#include <mono/metadata/mono-debug.h>
#include <mono/utils/mono-logger.h>

extern void mono_mkbundle_init();

// Tags used for popup menu items / compiler names in the editor view


@interface QCMonoPlugIn : QCPlugIn
{
	NSString *scriptSourceCode;
	NSData *monoImageData;
	
	MonoAssembly *monoAssembly;
	MonoMethod *monoInvocationMethod;
	MonoClass *monoScriptClass;
	MonoObject *monoScriptObject;
	MonoImage *monoImage;
	MonoDomain *monoScriptDomain;
	uint32_t monoObjectGCHandle;
	
	NSTimer *compileTimer;
	
	// The descriptions arrays are used to hold details about the ports
	// created to hold the script input and output values.  This allows
	// us to track which ports should be modified after a recompile
	// so we do not break connections unnecessarily 
	NSArray *inputPortDescriptions;
	NSArray *outputPortDescriptions;
	
	NSString *consoleText;
	
	BOOL compiling;
	BOOL compilerError;
	BOOL compilerWarning;
	BOOL compilerOK;
	
	BOOL needsCompile;
	
	NSInteger selectedCompilerTag;
}

@property (nonatomic, assign) NSInteger selectedCompilerTag;	

@property (nonatomic, retain) NSString *consoleText;
@property (nonatomic, retain) NSString *scriptSourceCode;
@property (nonatomic, retain) NSData *monoImageData;
@property (nonatomic, retain) NSAttributedString *attributedScriptSourceCode;

// Flags used by the UI to indicate compiler status
@property (nonatomic, assign) BOOL compiling;
@property (nonatomic, assign) BOOL compilerError;
@property (nonatomic, assign) BOOL compilerWarning;
@property (nonatomic, assign) BOOL compilerOK;

// Private method declared here to prevent compiler warnings
- (id) patch;

- (void) synchPorts;
- (BOOL) loadMonoImageData;
- (void) cleanupMono;
- (BOOL) compileAndLoadMonoScript;
- (void) createInputPortsForScriptFields;

@end

// Declare some private QC methods in QCPatch to prevent compiler warnings
@interface NSObject (QCPatchPrivate)

- (id) patch;
- (void) setNeedsExecution;
- (NSArray *) customInputPorts;
- (NSArray *) customOutputPorts;

@end