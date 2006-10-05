/* 
   FBSQLExpression.h

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

   This file is part of the FB Adaptor Library

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
// $Id: FBSQLExpression.h 1 2004-08-20 10:38:46Z znek $

#ifndef ___FB_SQLExpression_H___
#define ___FB_SQLExpression_H___

#include <GDLAccess/EOSQLExpression.h>

@class NSString, NSArray;
@class EOSQLQualifier, EOAdaptorChannel;

@interface FBSQLExpression : EOSQLExpression

+ (Class)selectExpressionClass;

@end

@interface FBSelectSQLExpression : EOSelectSQLExpression
{
  BOOL lock;
}

- (id)selectExpressionForAttributes:(NSArray *)attributes
  lock:(BOOL)flag
  qualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder
  channel:(EOAdaptorChannel *)channel;

@end

#endif
