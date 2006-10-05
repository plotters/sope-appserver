/* 
   NSString+PostgreSQL72.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2005 SKYRIX Software AG and Helge Hess

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

#if LIB_FOUNDATION_BOEHM_GC
#  include <objc/gc.h>
#endif

#import <objc/objc-api.h>
#include "common.h"
#import "NSString+PostgreSQL72.h"

@implementation NSString(PostgreSQL72MiscStrings)

- (NSString *)_pgModelMakeInstanceVarName {
  if ([self length] == 0)
    return @"";
  else {
    unsigned clen = 0;
    char     *s   = NULL;
    int      cnt, cnt2;

    clen = [self cStringLength];
    s = malloc(clen + 10);

    [self getCString:s maxLength:clen];
    
    for (cnt = cnt2 = 0; cnt < clen; cnt++, cnt2++) {
      if ((s[cnt] == '_') && (s[cnt + 1] != '\0')) {
        s[cnt2] = toupper(s[cnt + 1]);
        cnt++;
      }
      else if ((s[cnt] == '2') && (s[cnt + 1] != '\0')) {
        s[cnt2] = s[cnt];
        cnt++;
        cnt2++;
        s[cnt2] = toupper(s[cnt]);
      }
      else
        s[cnt2] = tolower(s[cnt]);
    }
    s[cnt2] = '\0';
    
    return [[[NSString alloc] 
                       initWithCStringNoCopy:s length:strlen(s) freeWhenDone:YES] 
                       autorelease];
  }
}

- (NSString *)_pgModelMakeClassName {
  if ([self length] == 0)
    return @"";
  else {
    unsigned clen = 0;
    char     *s   = NULL;
    int      cnt, cnt2;

    clen = [self cStringLength];
    s = malloc(clen + 10);

    [self getCString:s maxLength:clen];
    
    for (cnt = cnt2 = 0; cnt < clen; cnt++, cnt2++) {
      if ((s[cnt] == '_') && (s[cnt + 1] != '\0')) {
        s[cnt2] = toupper(s[cnt + 1]);
        cnt++;
      }
      else if ((s[cnt] == '2') && (s[cnt + 1] != '\0')) {
        s[cnt2] = s[cnt];
        cnt++;
        cnt2++;
        s[cnt2] = toupper(s[cnt]);
      }
      else
        s[cnt2] = tolower(s[cnt]);
    }
    s[cnt2] = '\0';

    s[0] = toupper(s[0]);

    return [[[NSString alloc] 
                       initWithCStringNoCopy:s length:strlen(s)
                       freeWhenDone:YES]
                       autorelease];
  }
}

- (NSString *)_pgStringWithCapitalizedFirstChar {
  NSCharacterSet *upperSet = [NSCharacterSet uppercaseLetterCharacterSet];
  
  if ([self length] == 0)
    return @"";
  else if ([upperSet characterIsMember:[self characterAtIndex:0]])
    return [[self copy] autorelease];
  else {
    NSMutableString *str = [NSMutableString stringWithCapacity:[self length]];

    [str appendString:[[self substringToIndex:1] uppercaseString]];
    [str appendString:[self substringFromIndex:1]];

    return [[str copy] autorelease];
  }
}

- (NSString *)_pgStripEndSpaces {
  if ([self length] > 0) {
    NSCharacterSet  *spaceSet;
    NSMutableString *str;
    unichar         (*charAtIndex)(id, SEL, int);
    NSRange         range;

    spaceSet = [NSCharacterSet whitespaceCharacterSet];
    str      = [NSMutableString stringWithCapacity:[self length]];

    charAtIndex  = (unichar (*)(id, SEL, int))
      [self methodForSelector:@selector(characterAtIndex:)];
    range.length = 0;

    for (range.location = ([self length] - 1);
         range.location >= 0;
         range.location++, range.length++) {
      unichar c;
      
      c = charAtIndex(self, @selector(characterAtIndex:), range.location);
      if (![spaceSet characterIsMember:c])
        break;
    }
    
    if (range.length > 0) {
      [str appendString:self];
      [str deleteCharactersInRange:range];
      return AUTORELEASE([str copy]);
    }
  }
  return AUTORELEASE([self copy]);
}
 
@end /* NSString(PostgreSQL72MiscStrings) */

void __link_NSStringPostgreSQL72() {
  // used to force linking of object file
  __link_NSStringPostgreSQL72();
}
