/* 
   NSCalendarDate+PGVal.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2005 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge@opengroupware.org)

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

#import <Foundation/NSString.h>
#include "PostgreSQL72Channel.h"
#include "common.h"

// Sybase Date: Oct 21 1997  9:52:26:000PM 
static NSString *PGSQL_DATETIME_FORMAT = @"%b %d %Y %I:%M:%S:000%p";

@implementation NSCalendarDate(PostgreSQL72Values)

/*
  Format: '2001-07-26 14:00:00+02'      (len 22)
          '2001-07-26 14:00:00+09:30'   (len 25)
           0123456789012345678901234
  
  Matthew: "07/25/2003 06:00:00 CDT".
*/

static Class      NSCalDateClass     = Nil;
static NSTimeZone *DefServerTimezone = nil;
static NSTimeZone *gmt   = nil;
static NSTimeZone *gmt01 = nil;
static NSTimeZone *gmt02 = nil;

+ (id)valueFromCString:(const char *)_cstr length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel
{
  static char buf[28]; // reused buffer THREAD
  char           *p;
  NSTimeZone     *attrTZ;
  NSCalendarDate *date;
  int            year, month, day, hour, min, sec, tzOffset = 0;
  
  if (_length == 0)
    return nil;
  
  if (_length != 22 && _length != 25) {
    // TODO: add support for "2001-07-26 14:00:00" (len=19)
    NSLog(@"ERROR(%s): unexpected string '%s' for date type '%@', returning "
	  @"now (expected format: '2001-07-26 14:00:00+02')", 
	  __PRETTY_FUNCTION__,
          _cstr, _type);
    return [NSCalendarDate date];
  }
  strncpy(buf, _cstr, 25);
  buf[25] = '\0';
  
  /* perform on reverse, so that we don't overwrite with null-terminators */
  
  if (_length == 22) {
    p = &(buf[19]);
    tzOffset = atoi(p) * 60;
  }
  else if (_length >= 25) {
    int mins;
    p = &(buf[23]);
    mins = atoi(p);
    buf[22] = '\0'; // the ':'
    p = &(buf[19]);
    tzOffset = atoi(p) * 60;
    tzOffset = tzOffset > 0 ? (tzOffset + mins) : (tzOffset - mins);
  }
  
  p = &(buf[17]); buf[19] = '\0'; sec   = atoi(p);
  p = &(buf[14]); buf[16] = '\0'; min   = atoi(p);
  p = &(buf[11]); buf[13] = '\0'; hour  = atoi(p);
  p = &(buf[8]);  buf[10] = '\0'; day   = atoi(p);
  p = &(buf[5]);  buf[7]  = '\0'; month = atoi(p);
  p = &(buf[0]);  buf[4]  = '\0'; year  = atoi(p);
  
  /* TODO: cache all timezones (just 26 ;-) */
  switch (tzOffset) {
  case 0:
    if (gmt == nil) {
      gmt = [[NSTimeZone timeZoneForSecondsFromGMT:0] retain];
      NSAssert(gmt, @"could not create GMT timezone?!");
    }
    attrTZ = gmt;
    break;
  case 60:
    if (gmt01 == nil) {
      gmt01 = [[NSTimeZone timeZoneForSecondsFromGMT:3600] retain];
      NSAssert(gmt01, @"could not create GMT+01 timezone?!");
    }
    attrTZ = gmt01;
    break;
  case 120:
    if (gmt02 == nil) {
      gmt02 = [[NSTimeZone timeZoneForSecondsFromGMT:7200] retain];
      NSAssert(gmt02, @"could not create GMT+02 timezone?!");
    }
    attrTZ = gmt02;
    break;
    
  default: {
    /* cache the first, "alternative" timezone */
    static int firstTZOffset = 0; // can use 0 since GMT is a separate case
    static NSTimeZone *firstTZ = nil;
    if (firstTZOffset == 0) {
      firstTZOffset = tzOffset;
      firstTZ = [[NSTimeZone timeZoneForSecondsFromGMT:(tzOffset*60)] retain];
    }
    
    attrTZ = (firstTZOffset == tzOffset)
      ? firstTZ
      : [NSTimeZone timeZoneForSecondsFromGMT:(tzOffset * 60)];
    break;
  }
  }
  
  if (NSCalDateClass == Nil) NSCalDateClass = [NSCalendarDate class];
  date = [NSCalDateClass dateWithYear:year month:month day:day
			 hour:hour minute:min second:sec
			 timeZone:attrTZ];
  if (date == nil) {
    NSLog(@"ERROR(%s): could not construct date from string '%s': "
          @"year=%i,month=%i,day=%i,hour=%i,minute=%i,second=%i, tz=%@",
          __PRETTY_FUNCTION__, _cstr,
          year, month, day, hour, min, sec, attrTZ);
  }
  return date;
}

+ (id)valueFromBytes:(const void *)_bytes length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel
{
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
  NSLog(@"%s: not implemented!", __PRETTY_FUNCTION__);
  return nil;
#else
  return [self notImplemented:_cmd];
#endif
}

- (NSString *)stringValueForPostgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
#if 0
  NSString   *format;
#endif
  EOQuotedExpression *expr;
  NSTimeZone *serverTimeZone;
  NSString   *format;
  NSString   *val;
  
  if ((serverTimeZone = [_attribute serverTimeZone]) == nil ) {
    if (DefServerTimezone == nil) {
      DefServerTimezone = [[NSTimeZone localTimeZone] retain];
      NSLog(@"Note: PostgreSQL72 adaptor using timezone '%@' as default",
	    DefServerTimezone);
    }
    serverTimeZone = DefServerTimezone;
  }
  
#if 0
  format = [_attribute calendarFormat];
#else /* hm, why is that? */
  format = @"%Y-%m-%d %H:%M:%S%z";
#endif
  if (format == nil)
    format = PGSQL_DATETIME_FORMAT;
  
  [self setTimeZone:serverTimeZone];
  
  val = [self descriptionWithCalendarFormat:format];
  expr = [[EOQuotedExpression alloc] initWithExpression:val
				     quote:@"\'" escape:@"\\'"];
  val = [[expr expressionValueForContext:nil] retain];
  [expr release];
  
  return [val autorelease];
}

@end /* NSCalendarDate(PostgreSQL72Values) */
