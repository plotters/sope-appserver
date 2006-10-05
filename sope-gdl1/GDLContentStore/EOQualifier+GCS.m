/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "EOQualifier+GCS.h"
#include "common.h"

@implementation EOQualifier(GCS)

- (void)_appendAndQualifier:(EOAndQualifier *)_q 
  toString:(NSMutableString *)_ms
{
  // TODO: move to EOQualifier category
  NSArray *qs;
  unsigned i, count;
  
  qs = [_q qualifiers];
  if ((count = [qs count]) == 0)
    return;
  
  for (i = 0; i < count; i++) {
    if (i != 0) [_ms appendString:@" AND "];
    if (count > 1) [_ms appendString:@"("];
    [[qs objectAtIndex:i] _gcsAppendToString:_ms];
    if (count > 1) [_ms appendString:@")"];
  }
}
- (void)_appendKeyValueQualifier:(EOKeyValueQualifier *)_q 
  toString:(NSMutableString *)_ms
{
  id val;
  
  [_ms appendString:[_q key]];
  
  if ((val = [_q value])) {
    SEL op = [_q selector];
    
    if ([val isNotNull]) {
      if (sel_eq(op, EOQualifierOperatorEqual))
	[_ms appendString:@" = "];
      else if (sel_eq(op, EOQualifierOperatorNotEqual))
	[_ms appendString:@" != "];
      else if (sel_eq(op, EOQualifierOperatorLessThan))
	[_ms appendString:@" < "];
      else if (sel_eq(op, EOQualifierOperatorGreaterThan))
	[_ms appendString:@" > "];
      else if (sel_eq(op, EOQualifierOperatorLessThanOrEqualTo))
	[_ms appendString:@" <= "];
      else if (sel_eq(op, EOQualifierOperatorGreaterThanOrEqualTo))
	[_ms appendString:@" >= "];
      else if (sel_eq(op, EOQualifierOperatorLike))
	[_ms appendString:@" LIKE "];
      else {
	[self logWithFormat:@"ERROR(%s): unsupported operation for null: %@",
	      __PRETTY_FUNCTION__, NSStringFromSelector(op)];
      }

      if ([val isKindOfClass:[NSNumber class]])
	[_ms appendString:[val stringValue]];
      else if ([val isKindOfClass:[NSString class]]) {
	[_ms appendString:@"'"];
	[_ms appendString:val];
	[_ms appendString:@"'"];
      }
      else {
	[self logWithFormat:@"ERROR(%s): unsupported value class: %@",
	      __PRETTY_FUNCTION__, NSStringFromClass([val class])];
      }
    }
    else {
      if (sel_eq(op, EOQualifierOperatorEqual))
	[_ms appendString:@" IS NULL"];
      else if (sel_eq(op, EOQualifierOperatorEqual))
	[_ms appendString:@" IS NOT NULL"];
      else {
	[self logWithFormat:@"ERROR(%s): invalid operation for null: %@",
	      __PRETTY_FUNCTION__, NSStringFromSelector(op)];
      }
    }
  }
  else
    [_ms appendString:@" IS NULL"];
}

- (void)_appendQualifier:(EOQualifier *)_q toString:(NSMutableString *)_ms {
  if (_q == nil) return;
  
  if ([_q isKindOfClass:[EOAndQualifier class]])
    [self _appendAndQualifier:(id)_q toString:_ms];
  else if ([_q isKindOfClass:[EOKeyValueQualifier class]])
    [self _appendKeyValueQualifier:(id)_q toString:_ms];
  else
    NSLog(@"ERROR: unknown qualifier: %@", _q);
}

- (void)_gcsAppendToString:(NSMutableString *)_ms {
  [self _appendQualifier:self toString:_ms];
}

@end /* EOQualifier(GCS) */
