/* 
   PGConnection.m

   Copyright (C) 2004-2005 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)
   
   This file is part of the PostgreSQL72 Adaptor Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#include "PGConnection.h"
#include "common.h"
#include <libpq-fe.h>

#if PG_MAJOR_VERSION >= 6 && PG_MINOR_VERSION > 3
#  define NG_HAS_NOTICE_PROCESSOR 1
#  define NG_HAS_BINARY_TUPLES    1
#  define NG_HAS_FMOD             1
#endif

#if PG_MAJOR_VERSION >= 7 && PG_MINOR_VERSION > 3
#  define NG_SET_CLIENT_ENCODING 1
#endif

@implementation PGConnection

static BOOL debugOn = NO;

- (id)initWithHostName:(NSString *)_host port:(NSString *)_port
  options:(NSString *)_options tty:(NSString *)_tty 
  database:(NSString *)_dbname 
  login:(NSString *)_login password:(NSString *)_pwd
{
  if ((self = [self init])) {
    NSException *error;
    
    error = [self connectWithHostName:_host port:_port options:_options 
		  tty:_tty database:_dbname login:_login password:_pwd];
    if (error != nil) {
      if (debugOn) 
	NSLog(@"%s: could not connect: %@", __PRETTY_FUNCTION__, error);
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [self finish];
  [super dealloc];
}

/* support */

- (const char *)_cstrFromString:(NSString *)_s {
  // TODO: fix API, check what the API string encoding is
  return [_s cString];
}
- (NSString *)_stringFromCString:(const char *)_cstr {
  return [NSString stringWithCString:_cstr];
}

/* accessors */

- (BOOL)isValid {
  return self->_connection != NULL ? YES : NO;
}

/* errors */

- (NSException *)_makeConnectException:(const char *)_func {
  return [NSException exceptionWithName:@"PGConnectFailed"
		      reason:[NSString stringWithCString:_func]
		      userInfo:nil];
}

/* connect operations */

- (void)_disconnect {
  if (self->_connection != NULL)
    [self finish];
}

- (NSException *)startConnectWithInfo:(NSString *)_conninfo {
  [self _disconnect];
  
  self->_connection = PQconnectStart([self _cstrFromString:_conninfo]);
  if (self->_connection == NULL)
    return [self _makeConnectException:__PRETTY_FUNCTION__];
  return nil;
}
// TODO: add method for polling connect status

- (NSException *)connectWithInfo:(NSString *)_conninfo {
  [self _disconnect];
  
  self->_connection = PQconnectdb([self _cstrFromString:_conninfo]);
  if (self->_connection == NULL)
    return [self _makeConnectException:__PRETTY_FUNCTION__];
  return nil;
}

- (NSException *)connectWithHostName:(NSString *)_host port:(NSString *)_port
  options:(NSString *)_options tty:(NSString *)_tty 
  database:(NSString *)_dbname 
  login:(NSString *)_login password:(NSString *)_pwd
{
  [self _disconnect];

  self->_connection = PQsetdbLogin([self _cstrFromString:_host],
				   [self _cstrFromString:_port],
				   [self _cstrFromString:_options],
				   [self _cstrFromString:_tty],
				   [self _cstrFromString:_dbname],
				   [self _cstrFromString:_login],
				   [self _cstrFromString:_pwd]);
  if (self->_connection == NULL)
    return [self _makeConnectException:__PRETTY_FUNCTION__];
  return nil;
}

- (void)finish {
  if (self->_connection != NULL) {
    PQfinish(self->_connection);
    self->_connection = NULL;
  }
}

- (BOOL)isConnectionOK {
  if (![self isValid]) 
    return NO;
  return PQstatus(self->_connection) == CONNECTION_OK ? YES : NO;
}

/* message callbacks */

- (BOOL)setNoticeProcessor:(void *)_callback context:(void *)_ctx {
#if NG_HAS_NOTICE_PROCESSOR
  PQsetNoticeProcessor(self->_connection, _callback, _ctx);
  return YES; // TODO: improve error handling
#else
  return NO;
#endif
}

/* settings */

- (BOOL)setClientEncoding:(NSString *)_encoding {
  return PQsetClientEncoding(self->_connection, 
			     [self _cstrFromString:_encoding]) == 0 ? YES : NO;
}

/* errors */

- (NSString *)errorMessage {
  if (![self isValid])
    return nil;
  
  return [self _stringFromCString:PQerrorMessage(self->_connection)];
}

/* queries */

- (void *)rawExecute:(NSString *)_sql {
  return PQexec(self->_connection, [self _cstrFromString:_sql]);
}
- (void)clearRawResults:(void *)_ptr {
  if (_ptr == NULL) return;
  PQclear(_ptr);
}

- (PGResultSet *)execute:(NSString *)_sql {
  void *handle;
  
  if ((handle = [self rawExecute:_sql]) == NULL)
    return nil;

  return [[[PGResultSet alloc] initWithConnection:self handle:handle]
	                autorelease];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]: ", self, NSStringFromClass([self class])];
  if ([self isValid])
    [ms appendFormat:@" connection=0x%p", self->_connection];
  else
    [ms appendString:@" not-connected"];
  [ms appendString:@">"];
  return ms;
}

@end /* PGConnection */

@implementation PGResultSet

/* wraps PGresult */

- (id)initWithConnection:(PGConnection *)_con handle:(void *)_handle {
  if (_handle == NULL) {
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    self->connection = [_con retain];
    self->results    = _handle;
  }
  return self;
}

- (void)dealloc {
  [self clear];
  [self->connection release];
  [super dealloc];
}

/* accessors */

- (BOOL)isValid {
  return self->results != NULL ? YES : NO;
}

- (BOOL)containsBinaryTuples {
#if NG_HAS_BINARY_TUPLES
  if (self->results == NULL) return NO;
  return PQbinaryTuples(self->results) ? YES : NO;
#else
  return NO;
#endif
}

- (NSString *)commandStatus {
  char *cstr;
  
  if (self->results == NULL)
    return nil;
  if ((cstr = PQcmdStatus(self->results)) == NULL)
    return nil;
  return [NSString stringWithCString:cstr];
}

- (NSString *)commandTuples {
  char *cstr;
  
  if (self->results == NULL)
    return nil;
  if ((cstr = PQcmdTuples(self->results)) == NULL)
    return nil;
  return [NSString stringWithCString:cstr];
}

/* fields */

- (unsigned)fieldCount {
  return self->results != NULL ? PQnfields(self->results) : 0;
}

- (NSString *)fieldNameAtIndex:(unsigned int)_idx {
  // TODO: charset
  if (self->results == NULL) return nil;
  return [NSString stringWithCString:PQfname(self->results, _idx)];
}

- (int)indexOfFieldNamed:(NSString *)_name {
  return PQfnumber(self->results, [_name cString]);
}

- (int)fieldSizeAtIndex:(unsigned int)_idx {
  if (self->results == NULL) return 0;
  return PQfsize(self->results, _idx);
}

- (int)modifierAtIndex:(unsigned int)_idx {
  if (self->results == NULL) return 0;
#if NG_HAS_FMOD
  return PQfmod(self->results, _idx);
#else
  return 0;
#endif
}

/* tuples */

- (unsigned int)tupleCount {
  if (self->results == NULL) return 0;
  return PQntuples(self->results);
}

- (BOOL)isNullTuple:(int)_tuple atIndex:(unsigned int)_idx {
  if (self->results == NULL) return NO;
  return PQgetisnull(self->results, _tuple, _idx) ? YES : NO;
}

- (void *)rawValueOfTuple:(int)_tuple atIndex:(unsigned int)_idx {
  if (self->results == NULL) return NULL;
  return PQgetvalue(self->results, _tuple, _idx);
}

- (int)lengthOfTuple:(int)_tuple atIndex:(unsigned int)_idx {
  if (self->results == NULL) return 0;
  return PQgetlength(self->results, _tuple, _idx);
}

/* operations */

- (void)clear {
  if (self->results == NULL) return;
  PQclear(self->results);
  self->results = NULL;
}

@end /* PGResultSet */
