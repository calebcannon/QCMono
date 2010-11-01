/*
 *  MonoUtils.h
 *  QCMono
 *
 *  Created by Caleb Cannon on 10/19/10.
 *  Copyright 2010 Caleb Cannon. All rights reserved.
 *
 */


#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

#include <mono/jit/jit.h>
#include <mono/metadata/assembly.h>
#include <mono/metadata/blob.h>
#include <mono/metadata/mono-config.h>
#include <mono/metadata/mono-debug.h>
#include <mono/utils/mono-logger.h>

NSNumber *mono_get_number_from_boolean_field(MonoObject *object, MonoClassField *field);
NSNumber *mono_get_number_from_single_field(MonoObject *object, MonoClassField *field);
NSNumber *mono_get_number_from_double_field(MonoObject *object, MonoClassField *field);
NSString *mono_get_string_from_string_field(MonoObject *object, MonoClassField *field);

NSArray *mono_get_string_array_from_field(MonoObject *object, MonoClassField *field);
NSDictionary *mono_get_array_from_field(MonoObject *object, MonoClassField *field);
NSDictionary *mono_get_foundation_dictionary_from_array(MonoArray *array);
NSArray *mono_get_foundation_array_from_array(MonoArray *array);
id mono_get_foundation_object_from_object(MonoObject *object);

MonoArray *mono_array_create_from_dictionary(MonoDomain *domain, NSDictionary *dict);
MonoArray *mono_array_create_from_array(MonoDomain *domain, NSArray *anArray);
MonoObject *mono_object_from_foundation_object(MonoDomain *domain, id object);

NSString *mono_get_qcport_type_for_type(int type);