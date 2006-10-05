/*
  Copyright (C) 2005 SKYRIX Software AG

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

#include <NGObjWeb/WOComponent.h>

@class NSArray;

@interface Main : WOComponent
{
}

@end

#include "WOSession+CoreData.h"
#include "common.h"

@implementation Main

- (id)initWithContext:(id)_ctx {
  if ((self = [super initWithContext:_ctx])) {
  }
  return self;
}

- (void)dealloc {
  [super dealloc];
}

/* accessors */

/* actions */

- (id)selectPost {
  [[self valueForKey:@"postDisplayGroup"] 
         selectObject:[self valueForKey:@"post"]];
  
#if 0 // this is not a detail ds
  [[self valueForKey:@"authorDisplayGroup"] 
         setMasterObject:[self valueForKey:@"post"]];
#endif
  return nil;
}

- (id)saveChanges {
  NSError *error;
  
  if (![[[self session] defaultManagedObjectContext] save:&error]) {
    // TODO: improve error handling
    [self errorWithFormat:@"Failed to save: %@", error];
  }
  return nil /* stay on page */;
}

- (id)rollback {
  [[[self session] defaultManagedObjectContext] rollback];
  
  // TODO: this does not refresh the datasources!

  return nil /* stay on page */;
}

@end /* Main */
