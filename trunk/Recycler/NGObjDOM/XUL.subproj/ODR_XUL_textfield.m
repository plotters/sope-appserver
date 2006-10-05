/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

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
// $Id$

#include "ODRDynamicXULTag.h"

@interface ODR_XUL_textfield : ODRDynamicXULTag
@end

#include "common.h"

@implementation ODR_XUL_textfield

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return YES;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  id formValue = nil;
    
  formValue = [_req formValueForKey:[_ctx elementID]];

  if (formValue) {
    if ([self isSettable:@"value" node:_node ctx:_ctx]) {
      // formValue = [self parseFormValue:formValue inContext:_ctx]; ????
      [self setString:formValue for:@"value" node:_node ctx:_ctx];
    }
  }
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  int size;
  id  value;

  size  = [self   intFor:@"size"  node:_node ctx:_ctx];
  value = [self valueFor:@"value" node:_node ctx:_ctx];

  if ([_ctx isInForm]) {
    [_response appendContentString:@"<input type=\"text\" name=\""];
    [_response appendContentHTMLAttributeValue:[_ctx elementID]]; // ???
    [_response appendContentString:@"\" value=\""];
    [_response appendContentHTMLAttributeValue:[value stringValue]];
    [_response appendContentCharacter:'"'];
    
    if (size > 0) {
      [_response appendContentString:@" size=\""];
      [_response appendContentString:[NSString stringWithFormat:@"%d", size]];
      [_response appendContentCharacter:'"'];
    }
  
    [_response appendContentString:@" />"];
  }
  else {
    [[_ctx component]
           logWithFormat:@"WARNING: xul:textfield is not in a form !"];
    [_response appendContentHTMLString:[value stringValue]];
  }
}

@end /* ODR_XUL_textfield */
