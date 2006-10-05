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

#include "NSString+DN.h"
#include "common.h"

static NSString *dnSeparator = @",";

static NSString *_stripSpaces(NSString *s) {
  NSString *result = nil;
  char     *cstr, *tmp;
  unsigned len, clen;
  
  if ([s rangeOfString:@" "].length == 0)
    return s;
  
  len = [s cStringLength];
  cstr = malloc(len + 1);
  [s getCString:cstr];

  tmp  = cstr;
  clen = len;

  /* strip leading spaces */
  while ((*tmp == ' ') && (*tmp != '\0')) {
    tmp++;
    clen--;
  }

  /* strip trailing spaces */
  while (clen > 0) {
    if (tmp[clen - 1] != ' ')
      break;
    clen--;
  }
  tmp[clen] = '\0';
  
  result = [NSString stringWithCString:tmp length:clen];
  if (cstr)
    free(cstr);
  return result;
}

static NSArray *cleanDNComponents(NSArray *_components) {
  unsigned i, count;
  id *cs;
  
  count = [_components count];
  
  if (count == 0)
    return nil;
  
  cs = calloc(count, sizeof(id));
  for (i = 0; i < count; i++) {
    NSString *rdn;
    
    rdn = [_components objectAtIndex:i];
    cs[i] = _stripSpaces(rdn);
  }
  _components = [NSArray arrayWithObjects:cs count:count];
  if (cs) free(cs);

  return _components;
}

@implementation NSString(DNSupport)

+ (NSString *)dnWithComponents:(NSArray *)_components {
  return [cleanDNComponents(_components) componentsJoinedByString:dnSeparator];
}

- (NSArray *)dnComponents {
  return cleanDNComponents([self componentsSeparatedByString:dnSeparator]);
}

- (NSString *)stringByAppendingDNComponent:(NSString *)_component {
  NSString *s;

  s = _stripSpaces(self);
  if (![s isNotEmpty])
    return _component;

  s = [dnSeparator stringByAppendingString:self];
  return [_component stringByAppendingString:s];
}

- (NSString *)stringByDeletingLastDNComponent {
  NSRange r;
  
  r = [self rangeOfString:dnSeparator];
  if (r.length == 0) return nil;
  
  return _stripSpaces([self substringFromIndex:(r.location + r.length)]);
}

- (NSString *)lastDNComponent {
  NSRange r;
  
  r = [self rangeOfString:dnSeparator];
  if (r.length == 0) return nil;
  
  return _stripSpaces([self substringToIndex:r.location]);
}

- (const char *)ldapRepresentation {
  return [self UTF8String];
}

- (NSDate *)ldapTimestamp {
  /* eg: '20000403055250Z' */
  unsigned   len;
  short      year, month, day, hour, minute, second;
  NSString   *tzname;
  NSTimeZone *tz;
  
  if ((len = [self length]) == 0)
    return nil;

  if (len < 14)
    return nil;
  
  year   = [[self substringWithRange:NSMakeRange(0,  4)] intValue];
  month  = [[self substringWithRange:NSMakeRange(4,  2)] intValue];
  day    = [[self substringWithRange:NSMakeRange(6,  2)] intValue];
  hour   = [[self substringWithRange:NSMakeRange(8,  2)] intValue];
  minute = [[self substringWithRange:NSMakeRange(10, 2)] intValue];
  second = [[self substringWithRange:NSMakeRange(12, 2)] intValue];

  /* timezone ??? */
  tzname = @"GMT";
  tz = [NSTimeZone timeZoneWithAbbreviation:tzname];

  return [NSCalendarDate dateWithYear:year month:month
                         day:day hour:hour minute:minute second:second
                         timeZone:tz];
}

@end /* NSString(DNSupport) */
