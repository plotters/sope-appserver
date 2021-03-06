#!/bin/sh

MODULENAME=$1
MFILE=$2
MODULECLASS="${MODULENAME}Mod_Module_Class"

#
# This tool is used to generate Apache module stub structures and classes.
#
# An Objective-C class is used to "emulate" a module object.
#

echo "creating structure for Apache module ${MODULENAME} in file ${MFILE} ..."

cat >$MFILE <<EOF
/*
  DO NOT EDIT, automagically generated !!
  
    Apache module: ${MODULENAME}
    Module file:   ${MFILE}
    Module class:  ${MODULECLASS}
    Date:          `date`
    Generated By:  ${USER}
    Generator:     $0
*/

#include "ApModuleBaseClass.h"
#include <httpd.h>
#include "http_config.h"
#import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>
#include "ApacheModule.h"

static module ${MODULENAME}_module_template;
module MODULE_VAR_EXPORT ${MODULENAME}_module;

@interface ${MODULECLASS} : ApModuleBaseClass
@end

@implementation ${MODULECLASS}

static ApacheModule *bundleHandler = nil;

+ (void)setBundleHandler:(ApacheModule *)_handler {
  if (_handler == bundleHandler)
    return;
  
  if ((bundleHandler != nil) && (_handler != nil)) {
    printf("WARNING(%s): handler of bundle %s already set !\n",
           __PRETTY_FUNCTION__,
           [[[NSBundle bundleForClass:self] description] cString]);
  }
  
  ASSIGN(bundleHandler, _handler);
}
+ (ApacheModule *)bundleHandler {
  return bundleHandler;
}

+ (void *)apacheTemplateModule {
  return &(${MODULENAME}_module_template);
}
+ (void *)apacheModuleStructure {
  return &${MODULENAME}_module;
}

static int _handleRequest(request_rec *_request) {
  return [${MODULECLASS} _handleRequest:_request];
}
+ (void *)handleRequestStubFunction {
  return &_handleRequest;
}

@end /* ${MODULECLASS} */

static void _moduleInit(server_rec *s, pool *p) {
  [${MODULECLASS} _moduleInit:s pool:p];
}

static void *_perDirConfCreate(pool *p, char *dirspec) {
  return [${MODULECLASS} _perDirConfCreate:dirspec pool:p];
}
static void *_perDirConfMerge(pool *p, void *baseConf, void *newConf) {
  return [${MODULECLASS} _perDirConfMerge:baseConf with:newConf pool:p];
}

static void *_perServerConfCreate(pool *p, server_rec *s) {
  return [${MODULECLASS} _perServerConfCreate:s pool:p];
}
static void *_perServerConfMerge(pool *p, void *baseConf, void *newConf) {
  return [${MODULECLASS} _perServerConfMerge:baseConf with:newConf pool:p];
}

static int _translateHandler(request_rec *_request) {
  return [${MODULECLASS} _translateHandler:_request];
}
static int _apCheckUserId(request_rec *_request) {
  return [${MODULECLASS} _apCheckUserId:_request];
}
static int _authChecker(request_rec *_request) {
  return [${MODULECLASS} _authChecker:_request];
}
static int _accessChecker(request_rec *_request) {
  return [${MODULECLASS} _accessChecker:_request];
}
static int _typeChecker(request_rec *_request) {
  return [${MODULECLASS} _typeChecker:_request];
}
static int _fixerUpper(request_rec *_request) {
  return [${MODULECLASS} _fixerUpper:_request];
}
static int _logger(request_rec *_request) {
  return [${MODULECLASS} _logger:_request];
}
static int _headerParser(request_rec *_request) {
  return [${MODULECLASS} _headerParser:_request];
}

static void _childInit(server_rec *_server, pool *_pool) {
  [${MODULECLASS} _childInit:_server pool:_pool];
}
static void _childExit(server_rec *_server, pool *_pool) {
  [${MODULECLASS} _childExit:_server pool:_pool];
}

static int _postReadRequest(request_rec *_request) {
  return [${MODULECLASS} _postReadRequest:_request];
}

static module ${MODULENAME}_module_template = {
    STANDARD_MODULE_STUFF,
    _moduleInit, _perDirConfCreate, _perDirConfMerge,
    _perServerConfCreate, _perServerConfMerge,
    NULL,  /* table of config file commands       */
    NULL,  /* [#8] MIME-typed-dispatched handlers */
    _translateHandler, _apCheckUserId, _authChecker, _accessChecker,
    _typeChecker, _fixerUpper, _logger, _headerParser,
    _childInit, _childExit, _postReadRequest
};

module MODULE_VAR_EXPORT ${MODULENAME}_module = {
    STANDARD_MODULE_STUFF,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL
};
EOF
