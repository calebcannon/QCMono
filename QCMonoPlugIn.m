//
//  QCMonoPlugIn.m
//  QCMono
//
//  Created by Caleb Cannon on 10/19/10.
//  Copyright (c) 2010 Caleb Cannon. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import "QCMonoPlugIn.h"
#import "MonoUtils.h"

NSInteger CompilerCSharp;


#define CompilerCSharp 1000
#define CompilerBoo 1001



#define	kQCPlugIn_Name				@"QCMono"
#define	kQCPlugIn_Description		@"This patch executes a script using the Mono IL framework with an arbitrary number of input / output parameters.  Currently supported languages are C# and Boo.  The Mono framework must be installed on the machine running the composition in order for the patch to work.  Each script must declare a \"Script\" class with a public function \"main()\" as an entry point.  Class variables beginning with \"input\" and \"output\" will be mapped to input and output ports in the Quartz Composer patch."

// Keys used for saving and loading serialized values
#define kScriptSourceCode			@"scriptSourceCode"
#define kMonoImageData				@"monoImageData"
#define kSelectedCompilerTag		@"selectedCompilerTag"

// Keys used in the port descriptions dictionaries
#define kQCPortType					@"QCPortTypeKey"
#define kQCPortKey					@"QCPortKey"
#define kQCPortAttributes			@"QCPortAttributesKey"

@implementation QCMonoPlugIn


@synthesize selectedCompilerTag;
@synthesize compilerError, compilerWarning, compilerOK, compiling;
@synthesize scriptSourceCode;
@synthesize monoImageData;
@synthesize consoleText;
@dynamic attributedScriptSourceCode;

+ (NSDictionary*) attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	return nil;
}

+ (QCPlugInExecutionMode) executionMode
{
	return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
	return kQCPlugInTimeModeNone;
}




- (NSArray *) sortedPropertyPortKeys
{
	NSMutableArray *sortedPropertyPortKeys = [NSMutableArray arrayWithCapacity:[inputPortDescriptions count] + [outputPortDescriptions count]];
	
	for (NSDictionary *portDesc in inputPortDescriptions)
		[sortedPropertyPortKeys addObject:[portDesc objectForKey:kQCPortKey]];
	for (NSDictionary *portDesc in outputPortDescriptions)
		[sortedPropertyPortKeys addObject:[portDesc objectForKey:kQCPortKey]];
	
	return sortedPropertyPortKeys;
}

- (id) init
{
	if(self = [super init]) 
	{
		NSError *error = nil;
		scriptSourceCode = [[NSString stringWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"default" ofType:@"cs"]
													  encoding:NSASCIIStringEncoding 
														 error:&error] retain];
		if (error)
		{
			// Something went wrong loading the default script ... forget about it
			scriptSourceCode = nil;
			needsCompile = NO;
		}
		selectedCompilerTag = CompilerCSharp;
	}
	
	return self;
}

- (void) finalize
{
	[self cleanupMono];

	[super finalize];
}

- (void) dealloc
{
	[super dealloc];
}

+ (NSArray*) plugInKeys
{
	return [NSArray arrayWithObjects:kScriptSourceCode, kMonoImageData, kSelectedCompilerTag, nil];
}

- (id) serializedValueForKey:(NSString*)key;
{
	if ([key isEqualToString:kScriptSourceCode])
		return self.scriptSourceCode;
	
	else if ([key isEqualToString:kMonoImageData])
		return self.monoImageData;
	
	else if ([key isEqualToString:kSelectedCompilerTag])
		return [NSNumber numberWithInt:selectedCompilerTag];
	
	else
		return [super serializedValueForKey:key];
}

- (void) setSerializedValue:(id)serializedValue forKey:(NSString*)key
{
	if ([key isEqualToString:kScriptSourceCode])
		self.scriptSourceCode = serializedValue;
	
	else if ([key isEqualToString:kMonoImageData])
		self.monoImageData = serializedValue;
	
	else if ([key isEqualToString:kSelectedCompilerTag])
		self.selectedCompilerTag = [serializedValue intValue];
	
	else
		[super setSerializedValue:serializedValue forKey:key];
}

- (QCPlugInViewController*) createViewController
{
	/*
	Return a new QCPlugInViewController to edit the internal settings of this plug-in instance.
	You can return a subclass of QCPlugInViewController if necessary.
	*/
	
	return [[QCPlugInViewController alloc] initWithPlugIn:self viewNibName:@"Settings"];
}

#pragma mark -
#pragma mark Accessors

// Start a timer to recompile the script.  This prevents the compiler from running every time
// the user types a character.
- (void) startCompileTimer
{			
  	if (!needsCompile)
	{
		needsCompile = YES;
		return;
	}
	
	if (compileTimer)
		[compileTimer invalidate];
	
	const double compileTimeInterval = 1.0;
	compileTimer = [NSTimer scheduledTimerWithTimeInterval:compileTimeInterval
													target:self
												  selector:@selector(compileTimerFired)
												  userInfo:nil
												   repeats:NO];
}

- (void) compileTimerFired
{
	compileTimer = nil;
	[self compileAndLoadMonoScript];
	[self createInputPortsForScriptFields];
}	

- (void) setScriptSourceCode:(NSString *)source
{
	[scriptSourceCode release];
	scriptSourceCode = [source retain];
	
	[self startCompileTimer];
}

- (void) setSelectedCompilerTag:(NSInteger)tag
{
	selectedCompilerTag = tag;
	
	[self startCompileTimer];
}

- (void) setAttributedScriptSourceCode:(NSAttributedString *)attributedString
{
	self.scriptSourceCode = [attributedString string];
}

- (NSAttributedString *)attributedScriptSourceCode
{
	if (self.scriptSourceCode)
		return [[[NSAttributedString alloc] initWithString:self.scriptSourceCode] autorelease];
	
	return nil;
}

- (void) setMonoImageData:(NSData *)data
{
	[monoImageData release];
	monoImageData = [data retain];
	
	[self loadMonoImageData];
}

#pragma mark -
#pragma mark Mono support

- (void) logMessage:(NSString *)message, ...
{
	va_list args;
    va_start(args, message);
	NSString *str = [[[NSString alloc] initWithFormat:message arguments:args] autorelease];
	NSLog(str,nil);
	self.consoleText = str;
}

- (BOOL) loadMonoImageData
{	
	if (self.monoImageData == nil)
		return FALSE;
	
	MonoImageOpenStatus status;

	// Initialize Mono if no domain can be found
	MonoDomain *rootMonoDomain = mono_domain_get();
	if (rootMonoDomain == nil) {
		mono_config_parse (nil);
		NSString *domainName = [NSString stringWithFormat:@"QC Mono Root Domain %p", self];
		rootMonoDomain = mono_jit_init_version([domainName UTF8String], NULL);
	}
	
	// The following is almost certainly not done correctly.  I have not been able to
	// properly free objects allocated in the root domain which tends to cause a crash
	// after a few recompiles.  Loading objects into a sub domain prevents any crashing
	if (monoScriptDomain)
		mono_domain_unload(monoScriptDomain);
	
	NSString *domainName = [NSString stringWithFormat:@"QC Mono Application Domain %p", self];
	monoScriptDomain = mono_domain_create_appdomain((char *)[domainName UTF8String], 0);
	mono_domain_set(monoScriptDomain, 0);

	/*
	if (monoImage)
	{
		mono_image_close(monoImage);
		monoImage = nil;
		monoAssembly = nil;
	}
	*/
	if (monoObjectGCHandle)
	{
		mono_gchandle_free(monoObjectGCHandle);
		monoObjectGCHandle = 0;
	}
	
	
	// Load the image from the NSData we got after compiling the script
	BOOL ref_only = NO;
	monoImage = mono_image_open_from_data_full((char *)[self.monoImageData bytes], [self.monoImageData length], YES, &status, ref_only);
	if (monoImage == nil || status != MONO_IMAGE_OK)
	{
		[self logMessage:@"Could not load image data.  Status: %i", status];
		return FALSE;
	}

	// Load the image assembly 
	monoAssembly = mono_assembly_load_from_full(monoImage, mono_image_get_name(monoImage), &status, ref_only);
	NSLog(@"Assembly: %p Image: %p Bytes: %p Data: %p", monoAssembly, monoImage, [self.monoImageData bytes], self.monoImageData);
	if (monoAssembly == nil) {
		[self logMessage:@"Could not load assembly from image.  Status: %i", status];
		//mono_image_close(monoImage), monoImage = nil;
		return FALSE;
	}
	
	//image = mono_assembly_get_image (monoAssembly);
	monoScriptClass = mono_class_from_name (monoImage, "", "Script");
	if (monoScriptClass == nil) {
		[self logMessage:@"Could not find a Script class. Scripts must contain a class 'Script' with a public method 'main()' as an entry point."];
		mono_assembly_close(monoAssembly), monoAssembly = nil;
		//mono_image_close(monoImage), monoImage = nil;
		return FALSE;
	}	
	
	// Why a public method would require these flags but the flags themselves are not exposed is beyond me
	#define METHOD_ATTRIBUTE_PUBLIC 0x0006
	#define METHOD_ATTRIBUTE_STATIC 0x0010
	#define M_ATTRS (METHOD_ATTRIBUTE_PUBLIC | METHOD_ATTRIBUTE_STATIC)
	monoInvocationMethod = mono_class_get_method_from_name_flags (monoScriptClass, "main", 0, M_ATTRS);
	if (monoInvocationMethod == nil) {
		[self logMessage:@"Could not find a Main method. Scripts must contain a class 'Script' with a public method 'main()' as an entry point."];
		mono_assembly_close(monoAssembly);
		monoAssembly = nil;
		//mono_image_close(monoImage);
		monoImage = nil;
		return FALSE;
	}
	
	// Initialize an object of the script class defined in the assembly
	monoScriptObject = mono_object_new(mono_domain_get(), monoScriptClass);
	if (monoScriptObject == nil) {
		[self logMessage:@"Unable to create new script object."];
		mono_assembly_close(monoAssembly), monoAssembly = nil;
		mono_image_close(monoImage), monoImage = nil;
		return FALSE;
	}

	mono_runtime_object_init(monoScriptObject);
	monoObjectGCHandle = mono_gchandle_new(monoScriptObject, 1);
	
	mono_domain_set(rootMonoDomain, 0);
	
	[self createInputPortsForScriptFields];

//	[[self patch] setNeedsExecution];
	[self execute:nil atTime:0.0 withArguments:nil];
	
	return TRUE;
}

- (BOOL) compileAndLoadMonoScript
{
	// Write the source to a temporary file

	if (self.scriptSourceCode == nil)
		return NO;
	
	
	// Get file paths for the source and executable
	const char *sourceFilePrefix = "qc-mono-tmp-";
	NSString *sourceFilePath = [[[NSString alloc] initWithCString:tempnam([NSTemporaryDirectory() cStringUsingEncoding:[NSString defaultCStringEncoding]], sourceFilePrefix)] autorelease];
	NSString *destFilePath = [sourceFilePath stringByAppendingPathExtension:@"mono.exe"];
	
	// Write the source to a temp file
	NSError *error = nil;
	[self.scriptSourceCode writeToFile:sourceFilePath atomically:NO encoding:[NSString defaultCStringEncoding] error:&error];
	if (error)
	{
		[self logMessage:@"Error writing source: %@", error];
		return NO;
	}
	
	// Create an execute the compilation task
	NSTask *compileTask = [[NSTask alloc] init];
	NSString *compileArgument;
	
	switch (self.selectedCompilerTag) 
	{
		case CompilerBoo:
			// I would like to let users declare inputs & outputs IB style, e.g. "public input int MyInput" would produce an input port
			compileArgument = [NSString stringWithFormat:@"booc -target:library -o:%@ %@", destFilePath, sourceFilePath];
			break;
		default: // CSharp
			compileArgument = [NSString stringWithFormat:@"gmcs %@ -target:library -d:input -d:output -out:%@", sourceFilePath, destFilePath];			
	}
	

	//NSLog(@"Args:%@", compileArguments);
	NSArray *compileArguments = [NSArray arrayWithObjects:
								 @"-l",
								 @"-c",
								 compileArgument,
								 nil];
	
	[compileTask setLaunchPath:@"/bin/bash"];
	[compileTask setArguments:compileArguments];
	[compileTask setCurrentDirectoryPath:[@"~" stringByExpandingTildeInPath]];

	// Configure a pipe so that NSTask doesn't mess with our output
	// Matching the input&output keeps the log where it belongs
	NSPipe *pipe = [NSPipe pipe];
	[compileTask setStandardOutput:pipe];
	[compileTask setStandardInput:[NSPipe pipe]];
	[compileTask setStandardError:pipe];
	
	// So that NSTask can use the PATH variables 
	//[compileTask setEnvironment:[[NSProcessInfo processInfo] environment]];
	[compileTask setLaunchPath:@"/bin/bash"];
	
	// Compile the script
	self.compilerError = NO;
	self.compilerWarning = NO;
	self.compilerOK = NO;
	self.compiling = TRUE;
	[compileTask launch];
	[compileTask waitUntilExit];
	self.compiling = FALSE;
	
	// Get the compiler log string
	NSData *outputData = [[pipe fileHandleForReading] readDataToEndOfFile];
	NSString *outputString = [[[NSString alloc] initWithData:outputData encoding:NSASCIIStringEncoding] autorelease];
	
	// Clean up the string
	outputString = [outputString stringByReplacingOccurrencesOfString:sourceFilePath withString:@""];
	self.consoleText = outputString;
	
	int compileStatus = [compileTask terminationStatus];

	// Load the compiled assembly if compilation was successful and update the compiler status flags
	if (compileStatus == 0)
	{
		if ([outputString length] == 0)
			self.compilerOK = YES;
		else
			self.compilerWarning = YES;

		// The accessor will load the assembly data into the Mono interpreter
		self.monoImageData = [NSData dataWithContentsOfFile:destFilePath];
	}
	else 
	{
		self.monoImageData = nil;
		self.compilerError = YES;
	}
		
	[compileTask release];
	
	return (compileStatus == 0);
}

// Returns TRUE is the port key is present and has the correct type.
// Removes the port and returns FALSE if the port name key is present but has the wrong type
// Returns FALSE if the port key is not present
- (BOOL) validateMonoPortWithType:(NSString *)type key:(NSString *)key fromPorts:(NSArray *)ports
{
	// The patch and custom*Ports methods are private methods used to get the current list of input and output ports	
	for (id port in ports)
	{
		if ([key isEqualToString:[port key]])
		{
			if ([type isEqualToString:QCPortTypeIndex] && [[[port class] description] isEqualToString:@"QCIndexPort"])
				return YES;
			if ([type isEqualToString:QCPortTypeNumber] && [[[port class] description] isEqualToString:@"QCNumberPort"])
				return YES;
			if ([type isEqualToString:QCPortTypeBoolean] && [[[port class] description] isEqualToString:@"QCBooleanPort"])
				return YES;
			if ([type isEqualToString:QCPortTypeString] && [[[port class] description] isEqualToString:@"QCStringPort"])
				return YES;
			if ([type isEqualToString:QCPortTypeStructure] && [[[port class] description] isEqualToString:@"QCStructureDictionaryPort"])
				return YES;
			else {
				NSLog(@"Remove port: %@ Ports: %@", key, ports);
				[self removeInputPortForKey:key];
				return NO;
			}
		}
	}
	
	return NO;
}

// Adds an input port if not present in the current patch input ports array
- (void) addMonoInputPortWithType:(NSString *)type forKey:(NSString *)key withAttributes:(NSDictionary *)attributes
{
	NSArray *inputPorts = [[self patch] customInputPorts];

	if (![self validateMonoPortWithType:type key:key fromPorts:inputPorts])
	{
		//NSLog(@"Added input type: %@ key: %@ attributes: %@", type, key, attributes);
		[self addInputPortWithType:type forKey:key withAttributes:attributes];
	}
}

- (void) addMonoOutputPortWithType:(NSString *)type forKey:(NSString *)key withAttributes:(NSDictionary *)attributes
{
	NSArray *outputPorts = [[self patch] customOutputPorts];

	// Add the port if it's not already there
	if (![self validateMonoPortWithType:type key:key fromPorts:outputPorts])
		[self addOutputPortWithType:type forKey:key withAttributes:attributes];
}

- (void) synchPorts
{
	for (NSDictionary *portDescription in inputPortDescriptions)
	{
		NSString *portType = [portDescription objectForKey:kQCPortType];
		NSString *portKey = [portDescription objectForKey:kQCPortKey];
		NSDictionary *portAttributes = [portDescription objectForKey:kQCPortAttributes];
		[self addMonoInputPortWithType:portType forKey:portKey withAttributes:portAttributes];
	}
	
	for (NSDictionary *portDescription in outputPortDescriptions)
	{
		NSString *portType = [portDescription objectForKey:kQCPortType];
		NSString *portKey = [portDescription objectForKey:kQCPortKey];
		NSDictionary *portAttributes = [portDescription objectForKey:kQCPortAttributes];
		[self addMonoOutputPortWithType:portType forKey:portKey withAttributes:portAttributes];
	}
}

- (void) createInputPortsForScriptFields
{
	if (monoScriptClass == nil || monoScriptObject == nil)
		return;
	
	NSMutableArray *newInputPortDescriptions = [NSMutableArray array];
	NSMutableArray *newOutputPortDescriptions = [NSMutableArray array];

	MonoType *field_type;
	int type_type;
	MonoObject *field_object;
	
	NSString *fieldName;
	id fieldValue;
	NSString *portType;
	NSMutableDictionary *portAttributes;
	
	void *iter = (void *) 0;
	MonoClassField *field;
	
	while ((field = mono_class_get_fields (monoScriptClass, &iter)) != NULL)
	{
		field_type = mono_field_get_type (field);		
		fieldName = [NSString stringWithUTF8String:mono_field_get_name(field)];		

		if ([fieldName length] > 5 && [fieldName hasPrefix:@"input"])
		{
			char *field_type_name = mono_type_get_name(field_type);
			type_type = mono_type_get_type(field_type);

			portAttributes = [NSMutableDictionary dictionary];
	
			portType = mono_get_qcport_type_for_type(type_type);
			
			NSLog(@"Input Field Type: %s", field_type_name);
			
			// NOTE: I would prefer that this be a case statement.  There are type identifiers but
			// I don't know how to get them from the field object
			if (strcmp(field_type_name, "System.Object[]") == 0) {
				fieldValue = nil;
			}
			else if (strcmp(field_type_name, "System.String[]") == 0)
			{
				/*
				 If a default value is specified create a menu for any inputs specified as an array of strings
				 */
				/* 
				 Note: adding a menu at this stage seems to crash QC for some reason.
				 The line setting the QCPortAttributeMenuItemKey should handle this.
				 Instead we will use an ordinary index port :(
				 TODO: find a way to create these such that it doesn't crash QC
				 */
				NSArray *menuItems = mono_get_string_array_from_field(monoScriptObject, field);
				if (menuItems && [menuItems count] > 0)
				{
					portType = QCPortTypeIndex;
					[portAttributes setObject:QCPortTypeIndex forKey:QCPortAttributeTypeKey];
					//[portAttributes setObject:menuItems forKey:QCPortAttributeMenuItemsKey];
					[portAttributes setObject:[NSNumber numberWithInt:0] forKey:QCPortAttributeDefaultValueKey];
					[portAttributes setObject:[NSNumber numberWithInt:0] forKey:QCPortAttributeMinimumValueKey];
					[portAttributes setObject:[NSNumber numberWithInt:[menuItems count]-1] forKey:QCPortAttributeMaximumValueKey];
				}
			}
			else if (strcmp(field_type_name, "System.Object[]") == 0)
			{
				portType = QCPortTypeStructure;
				[portAttributes setObject:QCPortTypeStructure forKey:QCPortAttributeTypeKey];
			}
			else 
			{
				field_object = mono_field_get_value_object(mono_domain_get(), field, monoScriptObject);
				fieldValue = mono_get_foundation_object_from_object(field_object);
			}
			
			[portAttributes setObject:[fieldName substringFromIndex:5] forKey:QCPortAttributeNameKey];
			
			[newInputPortDescriptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
								   portType, kQCPortType,
								   fieldName, kQCPortKey,
								   portAttributes, kQCPortAttributes,
								   nil]];
		}

		else if ([fieldName length] > 6 && [fieldName hasPrefix:@"output"])
		{
			int type_type = mono_type_get_type(field_type);
			portAttributes = [NSMutableDictionary dictionary];
			
			portType = mono_get_qcport_type_for_type(type_type);
			
			[portAttributes setObject:[fieldName substringFromIndex:6] forKey:QCPortAttributeNameKey];
			
			[newOutputPortDescriptions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									  portType, kQCPortType,
									  fieldName, kQCPortKey,
									  portAttributes, kQCPortAttributes,
									  nil]];
		}
	}
	
	// Remove input ports not present to the inputPorts array
	BOOL matchedPort;
	for (NSDictionary *portDescription in inputPortDescriptions)
	{
		matchedPort = FALSE;
		for (NSDictionary *newPortDescription in newInputPortDescriptions) {
			if ([[portDescription objectForKey:kQCPortKey] isEqualToString:[newPortDescription objectForKey:kQCPortKey]]) {
				if ([[portDescription objectForKey:kQCPortType] isEqualToString:[newPortDescription objectForKey:kQCPortType]]) {
					matchedPort = TRUE; 
					break;
				}
			}
		}

		if (!matchedPort)
			[self removeInputPortForKey:[portDescription objectForKey:kQCPortKey]];
	}

	for (NSDictionary *portDescription in outputPortDescriptions)
	{
		matchedPort = FALSE;
		for (NSDictionary *newPortDescription in newOutputPortDescriptions) {
			if ([[portDescription objectForKey:kQCPortKey] isEqualToString:[newPortDescription objectForKey:kQCPortKey]]) {
				if ([[portDescription objectForKey:kQCPortType] isEqualToString:[newPortDescription objectForKey:kQCPortType]]) {
					matchedPort = TRUE; 
					break;
				}
			}
		}
		
		if (!matchedPort)
			[self removeOutputPortForKey:[portDescription objectForKey:kQCPortKey]];
	}
	
	[inputPortDescriptions release];
	[outputPortDescriptions release];
	inputPortDescriptions = [newInputPortDescriptions retain];
	outputPortDescriptions = [newOutputPortDescriptions retain];
	
	[self synchPorts];
}

// Iterate through the current input ports and marshal their current values to the script data members
- (void) updateInputPortValues
{	
	MonoClassField *field;
	MonoType *field_type;
	void *field_new_value;
	int type_type;
	NSString *fieldName;
	
	void *iter = (void *) 0;
	while ((field = mono_class_get_fields (monoScriptClass, &iter)) != NULL)
	{
		field_type = mono_field_get_type (field);
		type_type = mono_type_get_type(field_type);		
		fieldName = [NSString stringWithUTF8String:mono_field_get_name(field)];		
		field_new_value = nil;
		
		switch (type_type) {
			case MONO_TYPE_END:
			case MONO_TYPE_VOID:
			case MONO_TYPE_BOOLEAN:
			{
				BOOL b = [[self valueForInputKey:fieldName] boolValue];
				field_new_value = &b;
				break;
			}
			case MONO_TYPE_CHAR:
			{
				char c = [[self valueForInputKey:fieldName] charValue];
				field_new_value = &c;
				break;
			}
			case MONO_TYPE_I1:
			{
				char c = [[self valueForInputKey:fieldName] charValue];
				field_new_value = &c;
				break;
			}
			case MONO_TYPE_U1:
			{
				unsigned char c = [[self valueForInputKey:fieldName] unsignedCharValue];
				field_new_value = &c;
				break;
			}
			case MONO_TYPE_I2:
			{
				short s = [[self valueForInputKey:fieldName] shortValue];
				field_new_value = &s;
				break;
			}
			case MONO_TYPE_U2:
			{
				unsigned short s = [[self valueForInputKey:fieldName] unsignedShortValue];
				field_new_value = &s;
				break;
			}
			case MONO_TYPE_I4:
			{
				int i = [[self valueForInputKey:fieldName] intValue];
				field_new_value = &i;
				break;
			}
			case MONO_TYPE_U4:
			{
				unsigned int i = [[self valueForInputKey:fieldName] unsignedIntValue];
				field_new_value = &i;
				break;
			}
			case MONO_TYPE_I8:
			{
				long l = [[self valueForInputKey:fieldName] longValue];
				field_new_value = &l;
				break;
			}
			case MONO_TYPE_U8:
			{
				unsigned long l = [[self valueForInputKey:fieldName] unsignedLongValue];
				field_new_value = &l;
				break;
			}
			case MONO_TYPE_R4:
			{
				float f = [[self valueForInputKey:fieldName] floatValue];
				field_new_value = &f;
				break;
			}
			case MONO_TYPE_R8:
			{
				double d = [[self valueForInputKey:fieldName] doubleValue];
				field_new_value = &d;
				break;
			}
			case MONO_TYPE_STRING:
			{
				const char *input_string = [[self valueForInputKey:fieldName] UTF8String];
				if (input_string != nil)
				{
					field_new_value = mono_string_new(mono_domain_get(), input_string);
					mono_field_set_value(monoScriptObject, field, field_new_value);
					field_new_value = nil;
				}
				break;
			}
			case MONO_TYPE_PTR:
			case MONO_TYPE_BYREF:
			case MONO_TYPE_VALUETYPE:
			case MONO_TYPE_CLASS:
			case MONO_TYPE_VAR:
			case MONO_TYPE_ARRAY:
			case MONO_TYPE_GENERICINST:
			case MONO_TYPE_TYPEDBYREF:
			case MONO_TYPE_I:
			case MONO_TYPE_U:
			case MONO_TYPE_FNPTR:
			case MONO_TYPE_OBJECT:
			case MONO_TYPE_SZARRAY:
			{
				NSDictionary *objectDict = [self valueForInputKey:fieldName];
				MonoArray *array = mono_array_create_from_dictionary(mono_domain_get(), objectDict);
				mono_field_set_value(monoScriptObject, field, array);
				field_new_value = nil;
				break;
			}
			case MONO_TYPE_MVAR:
			case MONO_TYPE_CMOD_REQD:
			case MONO_TYPE_CMOD_OPT:
			case MONO_TYPE_INTERNAL:			
			case MONO_TYPE_MODIFIER:
			case MONO_TYPE_SENTINEL:
			case MONO_TYPE_PINNED:
			case MONO_TYPE_ENUM:
			default:
				break;
		}
		
		if (field_new_value != nil)
			mono_field_set_value(monoScriptObject, field, field_new_value);
	}			
}

- (void) updateOutputPortValues
{
	
	MonoType *field_type;
	char *field_type_name;
	int type_type;
	MonoClassField *field;
	MonoObject *field_object;
	NSString *fieldName;
	id fieldValue;
	
	void *iter = (void *) 0;
	
	while ((field = mono_class_get_fields (monoScriptClass, &iter)) != NULL)
	{
		field_type = mono_field_get_type (field);
		type_type = mono_type_get_type(field_type);
		fieldName = [NSString stringWithUTF8String:mono_field_get_name(field)];		
		
		if ([fieldName length] > 6 && [fieldName hasPrefix:@"output"])
		{
			field_type_name = mono_type_get_name(field_type);
			fieldValue = nil;
			
			field_object = mono_field_get_value_object(mono_domain_get(), field, monoScriptObject);
			fieldValue = mono_get_foundation_object_from_object(field_object);
			
			// Assign the foundation value to the output port
			[self setValue:fieldValue forOutputKey:fieldName];
		}
	}
}


- (void) cleanupMono
{
	mono_jit_cleanup(mono_domain_get());
}

#pragma mark -
#pragma mark QC plugin execution methods

- (BOOL) startExecution:(id<QCPlugInContext>)context
{	
	return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
	NSLog(@"Enable execution");
	needsCompile = YES;
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{	
	// Execute the scripts Main method
	MonoObject *exc = nil;
	if (monoInvocationMethod)
	{
		[self updateInputPortValues];
		mono_runtime_invoke (monoInvocationMethod, monoScriptObject, nil, &exc);
		[self updateOutputPortValues];
	}
	else
		return NO;

	// If an exception was raised, write the details to standard out and raise an NSException
	if (exc != nil) {

		mono_print_unhandled_exception (exc);
		NSString *exceptionString = @"Exception raised in Mono invocation method.  See console for details";
		NSException *exception = [NSException exceptionWithName:@"Unhandled Exception" reason:exceptionString userInfo:nil];
		[exception raise];
		
		[self cleanupMono];
		
		return NO;
	}
	
	return YES;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
	/*	
	Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
	*/
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	/*
	Called by Quartz Composer when rendering of the composition stops: perform any required cleanup for the plug-in.
	*/
}

#pragma mark -
#pragma mark Misc

// Private method in super class - here to prevent compiler warnings
- (id) patch
{
	return [super patch];
}


@end
