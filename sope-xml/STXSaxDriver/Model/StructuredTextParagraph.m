/*
  Copyright (C) 2004 eXtrapola Srl

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

#include "StructuredTextParagraph.h"
#include "common.h"

@implementation StructuredTextParagraph

- (id)initWithString:(NSString *)aString {
  if ((self = [super init])) {
    _text = [aString retain];
  }
  return self;
}

- (void)dealloc {
  [_text release];
  [super dealloc];
}

/* accessors */

- (NSString *)text {
  return _text;
}

/* processing */

- (NSString *)textParsedWithDelegate:(id<StructuredTextRenderingDelegate>)_del
  inContext:(NSDictionary *)_ctx 
{
  NSString *text;

  self->_delegate = _del;
  text = [self parseText:[self text] inContext:_ctx];
  
  return (_del)
    ? [_del insertText:text inContext:_ctx]
    : text;
}

@end /* StructuredTextParagraph */
