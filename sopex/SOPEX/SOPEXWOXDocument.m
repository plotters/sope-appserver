/*
 Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

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
// $Id: SOPEXWOXDocument.m,v 1.3 2004/04/09 18:53:02 znek Exp $
//  Created by znek on Fri Mar 26 2004.


#import "SOPEXWOXDocument.h"
#import "SOPEXContentValidator.h"
#import "SOPEXTextView.h"


@implementation SOPEXWOXDocument

- (NSArray *)fileTypes
{
    return [NSArray arrayWithObject:@"wox"];
}


#pragma mark -
#pragma mark ### VALIDATION ###


- (NSError *)validateRepresentationForFileType:(NSString *)fileType
{
    id content;

    content = [[self textViewForFileType:fileType] string];
    return [SOPEXContentValidator validateWOXContent:content];
}

@end
