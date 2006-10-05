/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "NGLdapURL.h"
#include "NGLdapConnection.h"
#include "NGLdapEntry.h"
#include "EOQualifier+LDAP.h"
#include "common.h"
#include <string.h>

static inline BOOL isUrlAlpha(unsigned char _c) {
  return
    (((_c >= 'a') && (_c <= 'z')) ||
     ((_c >= 'A') && (_c <= 'Z')))
    ? YES : NO;
}
static inline BOOL isUrlDigit(unsigned char _c) {
  return ((_c >= '0') && (_c <= '9')) ? YES : NO;
}
static inline BOOL isUrlSafeChar(unsigned char _c) {
  switch (_c) {
    case '$': case '-': case '_': case '@':
    case '.': case '&': case '+':
      return YES;

    default:
      return NO;
  }
}
static inline BOOL isUrlExtraChar(unsigned char _c) {
  switch (_c) {
    case '!': case '*': case '"': case '\'':
    case '|': case ',':
      return YES;
  }
  return NO;
}
static inline BOOL isUrlEscapeChar(unsigned char _c) {
  return (_c == '%') ? YES : NO;
}
static inline BOOL isUrlReservedChar(unsigned char _c) {
  switch (_c) {
    case '=': case ';': case '/':
    case '#': case '?': case ':':
    case ' ':
      return YES;
  }
  return NO;
}

static inline BOOL isUrlXalpha(unsigned char _c) {
  if (isUrlAlpha(_c))      return YES;
  if (isUrlDigit(_c))      return YES;
  if (isUrlSafeChar(_c))   return YES;
  if (isUrlExtraChar(_c))  return YES;
  if (isUrlEscapeChar(_c)) return YES;
  return NO;
}

static inline BOOL isUrlHexChar(unsigned char _c) {
  if (isUrlDigit(_c))
    return YES;
  if ((_c >= 'a') && (_c <= 'f'))
    return YES;
  if ((_c >= 'A') && (_c <= 'F'))
    return YES;
  return NO;
}

static inline BOOL isUrlAlphaNum(unsigned char _c) {
  return (isUrlAlpha(_c) || isUrlDigit(_c)) ? YES : NO;
}

static inline BOOL isToBeEscaped(unsigned char _c) {
  return (isUrlAlphaNum(_c) || (_c == '_')) ? NO : YES;
}

static BOOL NGContainsUrlInvalidCharacters(const unsigned char *_buffer) {
  while (*_buffer) {
    if (isToBeEscaped(*_buffer))
      return YES;
    _buffer++;
  }
  return NO;
}
static void NGEscapeUrlBuffer
(const unsigned char *_source, unsigned char *_dest) {
  register const unsigned char *src = (void*)_source;
  while (*src) {
    //if (*src == ' ') { // a ' ' becomes a '+'
    //  *_dest = '+'; _dest++;
    //}
    if (!isToBeEscaped(*src)) {
      *_dest = *src;
      _dest++;
    } 
    else { // any other char is escaped ..
      *_dest = '%'; _dest++;
      sprintf((char *)_dest, "%02X", (unsigned)*src);
      _dest += 2;
    }
    src++;
  }
  *_dest = '\0';
}
static NSString *NGEscapeUrlString(NSString *_source) {
  unsigned len;
  char     *cstr;
  NSString *s;

  if ((len = [_source cStringLength]) == 0)
    return _source;

  cstr = malloc(len + 3);
  [_source getCString:cstr];
  cstr[len] = '\0';
  
  if (NGContainsUrlInvalidCharacters((unsigned char *)cstr)) {
    // needs to be escaped ?
    char *buffer = NULL;
    
    buffer = NGMallocAtomic([_source cStringLength] * 3 + 2);
    NGEscapeUrlBuffer((unsigned char *)cstr, (unsigned char *)buffer);
    
    s = [[[NSString alloc]
                    initWithCStringNoCopy:buffer
                    length:strlen(buffer)
                    freeWhenDone:YES] autorelease];
  }
  else
    s = [[_source copy] autorelease];
  
  free(cstr);
  return s;
}

@implementation NGLdapURL

+ (id)ldapURLWithString:(NSString *)_url {
  if (!ldap_is_ldap_url((char *)[_url UTF8String]))
    return nil;

  return [[[self alloc] initWithString:_url] autorelease];
}

- (id)initWithString:(NSString *)_url {
  LDAPURLDesc *urld = NULL;
  unsigned attrCount, i;
  int err;

  self->scope = -1;

  if ((err = ldap_url_parse((char *)[_url UTF8String], &urld)) != 0) {
    [self release];
    return nil;
  }
  if (urld == NULL) {
    [self release];
    return nil;
  }
    
  self->host   = [[NSString alloc] initWithCString:urld->lud_host];
  self->port   = urld->lud_port;
  self->base   = [[NSString alloc] initWithCString:urld->lud_dn];
  self->scope  = urld->lud_scope;
  self->filter = [[NSString alloc] initWithCString:urld->lud_filter];
  
  if (urld != NULL && urld->lud_attrs != NULL) {
    register char *tmp, **a;
    a = urld->lud_attrs;
    for (i = 0; (tmp = a[i]); i++)
      ;
    attrCount = i;
  }
  else
    attrCount = 0;
    
  if (attrCount > 0) {
    id *attrs;

    attrs = calloc(attrCount+1, sizeof(id));
    
    for (i = 0; i < attrCount; i++)
      attrs[i] = [[NSString alloc] initWithCString:urld->lud_attrs[i]];
      
    self->attributes = [[NSArray alloc] initWithObjects:attrs count:attrCount];

    for (i = 0; i < attrCount; i++)
      [attrs[i] release];
    if (attrs) free(attrs);
  }
  
  if (urld) ldap_free_urldesc(urld);
  
  return self;
}

- (id)init {
  return [self initWithString:nil];
}

- (void)dealloc {
  [self->host       release];
  [self->base       release];
  [self->filter     release];
  [self->attributes release];
  [super dealloc];
}

/* accessors */

- (NSString *)hostName {
  return self->host;
}
- (NSHost *)host {
  return [NSHost hostWithName:[self hostName]];
}

- (int)port {
  return self->port;
}
- (NSString *)baseDN {
  return self->base;
}
- (int)scope {
  return self->scope;
}

- (NSString *)searchFilter {
  return self->filter;
}
- (EOQualifier *)searchFilterQualifier {
  EOQualifier *q;
  
  if (self->filter == nil)
    return nil;

  q = nil;
  q = [[EOQualifier alloc] initWithLDAPFilterString:self->filter];

  return [q autorelease];
}

- (NSArray *)attributes {
  return self->attributes;
}

/* perform fetches */

- (NGLdapConnection *)openConnection {
  NGLdapConnection *con;

  con = [[NGLdapConnection alloc] initWithHostName:[self hostName]
                                  port:[self port] ? [self port] : 389];
  return [con autorelease];
}

- (NSEnumerator *)fetchEntries {
  NGLdapConnection *con;

  if ((con = [self openConnection]) == nil)
    return nil;
  
  switch (self->scope) {
    case LDAP_SCOPE_ONELEVEL:
      return [con flatSearchAtBaseDN:[self baseDN]
                  qualifier:[self searchFilterQualifier]
                  attributes:[self attributes]];
      
    case LDAP_SCOPE_SUBTREE:
      return [con deepSearchAtBaseDN:[self baseDN]
                  qualifier:[self searchFilterQualifier]
                  attributes:[self attributes]];
      
    case LDAP_SCOPE_BASE:
      return [con baseSearchAtBaseDN:[self baseDN]
                  qualifier:[self searchFilterQualifier]
                  attributes:[self attributes]];
  }

  return nil;
}
- (NGLdapEntry *)fetchEntry {
  return [[self fetchEntries] nextObject];
}

/* url */

- (NSString *)urlString {
  NSMutableString *s;
  NSString *is;

  s = [[NSMutableString alloc] initWithCapacity:200];

  [s appendString:@"ldap://"];
  [s appendString:self->host != nil ? self->host : (NSString *)@"localhost"];
  if (self->port > 0) [s appendFormat:@":%i", self->port];

  [s appendString:@"/"];
  is = self->base;
  is = NGEscapeUrlString(is);
  [s appendString:is];
  
  if ((self->attributes != nil) || (self->scope != -1) || (self->filter != nil)){
    [s appendString:@"?"];
    is = [self->attributes componentsJoinedByString:@","];
    is = NGEscapeUrlString(is);
    [s appendString:is];
  }
  if ((self->scope != -1) || (self->filter != nil)) {
    [s appendString:@"?"];
    switch (self->scope) {
      case LDAP_SCOPE_ONELEVEL:
        [s appendString:@"one"];
        break;
      case LDAP_SCOPE_SUBTREE:
        [s appendString:@"sub"];
        break;
      case LDAP_SCOPE_BASE:
      default:
        [s appendString:@"base"];
        break;
    }
  }
  if (self->filter) {
    [s appendString:@"?"];
    is = self->filter;
    is = NGEscapeUrlString(is);
    [s appendString:is];
  }

  is = [s copy];
  [s release];
  return [is autorelease];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[[self class] allocWithZone:_zone] initWithString:[self urlString]];
}

/* description */

- (NSString *)description {
  return [self urlString];
}

@end /* NGLdapURL */
