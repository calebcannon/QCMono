/*
 *  MonoUtils.c
 *  QCMono
 *
 *  Created by Caleb Cannon on 10/19/10.
 *  Copyright 2010 Caleb Cannon. All rights reserved.
 *
 */

#include "MonoUtils.h"


NSArray *qcm_get_string_array_from_field(MonoObject *object, MonoClassField *field)
{
	NSArray *result = [NSArray array];
	
	MonoArray *array = nil;
	MonoString *string;
	NSString *nsstring;
	mono_field_get_value(object, field, &array);
	
	if (array == nil)
		return nil;
	
	unsigned int elements = mono_array_length(array);
	unsigned int i;
	for (i = 0; i < elements; i++)
	{
		string = mono_array_get(array, MonoString *, i);
		
		char *buff = mono_string_to_utf8(string);
		
		if (buff != nil)
		{
			nsstring = [NSString stringWithUTF8String:buff];
			result = [result arrayByAddingObject:nsstring];
		}
	}

	return result;
}

NSDictionary *qcm_get_array_from_field(MonoObject *object, MonoClassField *field)
{
	MonoArray *array = nil;
	mono_field_get_value(object, field, &array);
	return qcm_get_foundation_dictionary_from_array(array);
}

NSArray *qcm_get_foundation_array_from_array(MonoArray *array)
{
	if (array == nil)
		return nil;
	
	NSMutableArray *nsarray = [NSMutableArray array];
	
	unsigned int elements = mono_array_length(array);
	unsigned int i;
	for (i = 0; i < elements; i++)
	{
		MonoObject *arrayObject = mono_array_get(array, MonoObject *, i);
		id foundationObject = mono_get_foundation_object_from_object(arrayObject);
		
		if (foundationObject == nil)
			break;
		

		[nsarray addObject:foundationObject];
	}
	
	return nsarray;
}

NSDictionary *qcm_get_foundation_dictionary_from_array(MonoArray *array)
{
	if (array == nil)
		return nil;
		
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	
	unsigned int elements = mono_array_length(array);
	unsigned int i;
	for (i = 0; i < elements; i++)
	{
		MonoObject *arrayObject = mono_array_get(array, MonoObject *, i);
		id foundationObject = mono_get_foundation_object_from_object(arrayObject);
		
		if (foundationObject == nil)
			break;
		
		else
			[dictionary setObject:foundationObject
						   forKey:[NSString stringWithFormat:@"%i", [dictionary count]]];
	}
	
	return dictionary;
}

NSDictionary *mono_get_foundation_dictionary_from_dictionary(MonoArray *array)
{
	if (array == nil)
		return nil;

	// Dictionaries are returned from Mono as a two dimensional array of arrays: MonoArray *array[2][n] 
	// Fetching them and converting them to NSDictionaries this way seems hackish.

	MonoObject *keyArrayObject = mono_array_get(array, MonoObject *, 0);
	NSArray *keys = qcm_get_foundation_array_from_array((MonoArray *)keyArrayObject);
	
	MonoObject *valueArrayObject = mono_array_get(array, MonoObject *, 1);
	NSArray *values  = qcm_get_foundation_array_from_array((MonoArray *)valueArrayObject);

	NSDictionary *dictionary = [NSDictionary dictionaryWithObjects:values forKeys:keys];
	
	return dictionary;
}


id mono_get_foundation_object_from_object(MonoObject *object)
{	
	if (object == nil)
		return nil;

	MonoClass *class = mono_object_get_class(object);
	MonoType *type = mono_class_get_type(class);
	int type_type = mono_type_get_type(type);
	const char *class_name = mono_class_get_name(class);
	
	void *value;

	// TODO: fix me
	if (mono_type_is_byref(type))
		NSLog(@"Type is byref");
	else 
		NSLog(@"Type is NOT byref");
	
	if (mono_type_is_pointer(type))
	{
		value = object;
	}
	else if (mono_type_is_struct(type))
	{
		value = mono_object_unbox(object);
	}
	else if (mono_type_is_void(type))
	{
		value = mono_object_unbox(object);
	}
	else if (mono_type_is_reference(type))
	{
		value = object;
	}
	else 
	{
		NSLog(@"Type is unknown");
		value = mono_object_unbox(object);
	}

	
	switch (type_type) 
	{
		case MONO_TYPE_END:
		case MONO_TYPE_VOID:
		case MONO_TYPE_BOOLEAN:
			return [NSNumber numberWithBool:*(BOOL *)value];
			
		case MONO_TYPE_CHAR:
			return [NSNumber numberWithChar:*(char *)value];
			
		case MONO_TYPE_I1:
			return [NSNumber numberWithChar:*(char *)value];
			
		case MONO_TYPE_U1:
			return [NSNumber numberWithUnsignedChar:*(unsigned char *)value];
			
		case MONO_TYPE_I2:
			return [NSNumber numberWithShort:*(short *)value];
			
		case MONO_TYPE_U2:
			return [NSNumber numberWithUnsignedShort:*(unsigned short *)value];
			
		case MONO_TYPE_I4:
			return [NSNumber numberWithInt:*(int *)value];
			
		case MONO_TYPE_U4:
			return [NSNumber numberWithInt:*(unsigned int *)value];
			
		case MONO_TYPE_I8:
			return [NSNumber numberWithLong:*(long *)value];
			
		case MONO_TYPE_U8:
			return [NSNumber numberWithUnsignedLong:*(unsigned long *)value];
			
		case MONO_TYPE_R4:
			return [NSNumber numberWithFloat:*(float *)value];
			
		case MONO_TYPE_R8:
			return [NSNumber numberWithDouble:*(double *)value];
			
		case MONO_TYPE_STRING:
		{
			MonoString *string = (MonoString *)object;
			char *buff = mono_string_to_utf8(string);
			return [NSString stringWithUTF8String:buff];
			
			return [NSString stringWithUTF8String:mono_string_to_utf8((MonoString *)object)];
		}			
		
		case MONO_TYPE_PTR:
		case MONO_TYPE_BYREF:
		case MONO_TYPE_VALUETYPE:
		case MONO_TYPE_CLASS:
		case MONO_TYPE_VAR:
		case MONO_TYPE_ARRAY:
			return qcm_get_foundation_dictionary_from_array((MonoArray *)object);
		
		case MONO_TYPE_GENERICINST:
		case MONO_TYPE_TYPEDBYREF:
		case MONO_TYPE_I:
		case MONO_TYPE_U:
		case MONO_TYPE_FNPTR:
		case MONO_TYPE_OBJECT:
		case MONO_TYPE_SZARRAY:
			if (strstr(class_name, "Dictionary") != nil)
				return mono_get_foundation_dictionary_from_dictionary((MonoArray *)object);
			else
				return qcm_get_foundation_dictionary_from_array((MonoArray *)object);

		case MONO_TYPE_MVAR:
		case MONO_TYPE_CMOD_REQD:
		case MONO_TYPE_CMOD_OPT:
		case MONO_TYPE_INTERNAL:			
		case MONO_TYPE_MODIFIER:
		case MONO_TYPE_SENTINEL:
		case MONO_TYPE_PINNED:
		case MONO_TYPE_ENUM:
		default:
			return nil;
	}
	

	return nil;
}


MonoArray *qcm_array_create_from_dictionary(MonoDomain *domain, NSDictionary *aDictionary)
{	
	MonoArray *array;
	
	if (aDictionary && [aDictionary isKindOfClass:[NSDictionary class]])
	{
		array = mono_array_new(domain, mono_get_object_class(), [aDictionary count]);
		
		for (int i = 0; i < [aDictionary count]; i++)
		{
			MonoObject *object = qcm_object_from_foundation_object(domain, [[aDictionary allValues] objectAtIndex:i]);
			mono_array_set(array, MonoObject *, i, object);
		}
	}
	else {
		// Create an empty array
		array = mono_array_new(domain, mono_get_object_class(), 0);
	}
	
	
	return array;
}

MonoArray *qcm_array_create_from_array(MonoDomain *domain, NSArray *anArray)
{
	MonoArray *array;
	
	if (anArray && [anArray isKindOfClass:[NSArray class]])
	{	
		array = mono_array_new(domain, mono_get_object_class(), [anArray count]);
		
		for (int i = 0; i < [anArray count]; i++)
		{
			MonoObject *object = qcm_object_from_foundation_object(domain, [anArray objectAtIndex:i]);
			mono_array_set(array, MonoObject *, i, object);
		}
	}
	else 
	{
		// Create an empty array
		array = mono_array_new(domain, mono_get_object_class(), 0);
	}
	
	
	return array;
}

MonoObject *qcm_object_from_foundation_object(MonoDomain *domain, id object)
{
	if ([object isKindOfClass:[NSNumber class]])
	{
		double val = [object doubleValue];
		MonoObject *object = mono_value_box(domain, mono_get_double_class(), &val);
		return object;
	}
	
	else if ([object isKindOfClass:[NSString class]])
	{
		const char *buff = [object UTF8String];
		MonoObject *string = (MonoObject *)mono_string_new(domain, buff);
		return string;
	}
	
	else if ([object isKindOfClass:[NSDictionary class]])
	{
		NSDictionary *dict = (NSDictionary *)object;
		MonoArray *object = qcm_array_create_from_dictionary(domain, dict);
		return (MonoObject *)object;
	}

	else if ([object isKindOfClass:[NSArray class]])
	{
		NSArray *array = (NSArray *)object;
		MonoArray *object = qcm_array_create_from_array(domain, array);
		return (MonoObject *)object;
	}
	
	return nil;
}

NSString *qcm_get_qcport_type_for_type(int type)
{	
	switch (type) 
	{
		case MONO_TYPE_END:
		case MONO_TYPE_VOID:
		case MONO_TYPE_BOOLEAN:
			return QCPortTypeBoolean;
			
		case MONO_TYPE_CHAR:
			return QCPortTypeIndex;
			
		case MONO_TYPE_I1:
			return QCPortTypeIndex;
			
		case MONO_TYPE_U1:
			return QCPortTypeIndex;
			
		case MONO_TYPE_I2:
			return QCPortTypeIndex;
			
		case MONO_TYPE_U2:
			return QCPortTypeIndex;
			
		case MONO_TYPE_I4:
			return QCPortTypeIndex;
			
		case MONO_TYPE_U4:
			return QCPortTypeIndex;
			
		case MONO_TYPE_I8:
			return QCPortTypeIndex;
			
		case MONO_TYPE_U8:
			return QCPortTypeIndex;
			
		case MONO_TYPE_R4:
			return QCPortTypeNumber;
			
		case MONO_TYPE_R8:
			return QCPortTypeNumber;
			
		case MONO_TYPE_STRING:
			return QCPortTypeString;
			
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
			return QCPortTypeStructure;
		case MONO_TYPE_MVAR:
		case MONO_TYPE_CMOD_REQD:
		case MONO_TYPE_CMOD_OPT:
		case MONO_TYPE_INTERNAL:			
		case MONO_TYPE_MODIFIER:
		case MONO_TYPE_SENTINEL:
		case MONO_TYPE_PINNED:
		case MONO_TYPE_ENUM:
		default:
			return nil;
	}	
}


