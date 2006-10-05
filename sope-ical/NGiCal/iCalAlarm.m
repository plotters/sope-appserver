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

#include "iCalAlarm.h"
#include "common.h"

@implementation iCalAlarm

- (void)dealloc {
  [self->trigger        release];
  [self->comment        release];
  [self->action         release];
  [self->attach         release];
  [self->recurrenceRule release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  iCalAlarm *new;
  
  new = [super copyWithZone:_zone];
  
  new->trigger        = [self->trigger copyWithZone:_zone];
  new->comment        = [self->comment copyWithZone:_zone];
  new->action         = [self->action copyWithZone:_zone];
  new->attach         = [self->attach copyWithZone:_zone];
  new->recurrenceRule = [self->recurrenceRule copyWithZone:_zone];
  
  return new;
}

/* accessors */

- (void)setTrigger:(id)_value {
  ASSIGN(self->trigger, _value);
}
- (id)trigger {
  return self->trigger;
}

- (void)setAttach:(id)_value {
  ASSIGN(self->attach, _value);
}
- (id)attach {
  return self->attach;
}

- (void)setComment:(NSString *)_value {
  ASSIGNCOPY(self->comment, _value);
}
- (NSString *)comment {
  return self->comment;
}

- (void)setAction:(NSString *)_value {
  ASSIGNCOPY(self->action, _value);
}
- (NSString *)action {
  return self->action;
}

- (void)setRecurrenceRule:(NSString *)_recurrenceRule {
  ASSIGN(self->recurrenceRule, _recurrenceRule);
}
- (NSString *)recurrenceRule {
  return self->recurrenceRule;
}

/* descriptions */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->action)
    [ms appendFormat:@" action=%@", self->action];
  if (self->comment)
    [ms appendFormat:@" comment=%@", self->comment];
  if (self->trigger)
    [ms appendFormat:@" trigger=%@", self->trigger];
  if (self->recurrenceRule)
    [ms appendFormat:@" recurrenceRule=%@", self->recurrenceRule];
  
  [ms appendString:@">"];
  return ms;
}

@end /* iCalAlarm */
