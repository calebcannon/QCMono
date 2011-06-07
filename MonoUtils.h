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

NSArray *qcm_get_string_array_from_field(MonoObject *object, MonoClassField *field);
NSDictionary *qcm_get_array_from_field(MonoObject *object, MonoClassField *field);
NSDictionary *qcm_get_foundation_dictionary_from_array(MonoArray *array);
NSArray *qcm_get_foundation_array_from_array(MonoArray *array);
id mono_get_foundation_object_from_object(MonoObject *object);

MonoArray *qcm_array_create_from_dictionary(MonoDomain *domain, NSDictionary *dict);
MonoArray *qcm_array_create_from_array(MonoDomain *domain, NSArray *anArray);
MonoObject *qcm_object_from_foundation_object(MonoDomain *domain, id object);

NSString *qcm_get_qcport_type_for_type(int type);