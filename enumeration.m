//
//  enumeration.m
//  
//
//  Created by Bobby Radford on 1/30/24.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

void enumeratePropertiesOfObject(id object) __attribute__((used));

void enumeratePropertiesOfObject(id object) {
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([object class], &outCount);
    for(i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);
        NSLog(@"Property: %s", name);
    }
    free(properties);
}
