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

#include <NGExtensions/NSString+Encoding.h>
#include <NGExtensions/NSObject+Logs.h>
#include "common.h"

#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
#  import <CoreFoundation/CoreFoundation.h>
#else
#  include <iconv.h>
#  import <Foundation/NSByteOrder.h>
#endif

// TODO: should move different implementations to different files ...

#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY

@interface NSString(Encoding_PrivateAPI)
+ (NSStringEncoding)stringEncodingForEncodingNamed:(NSString *)encoding;
@end

@implementation NSString(Encoding)

+ (NSStringEncoding)stringEncodingForEncodingNamed:(NSString *)_encoding
{
  CFStringEncoding cfEncoding;

  if(_encoding == nil)
    return 0;

  _encoding = [_encoding lowercaseString];
  cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)_encoding);
  if(cfEncoding == kCFStringEncodingInvalidId)
    return 0;
  return CFStringConvertEncodingToNSStringEncoding(cfEncoding);
}

+ (NSString *)stringWithData:(NSData *)_data
  usingEncodingNamed:(NSString *)_encoding
{
  NSStringEncoding encoding;

  encoding = [NSString stringEncodingForEncodingNamed:_encoding];
  return [[[NSString alloc] initWithData:_data encoding:encoding] autorelease];
}

- (NSData *)dataUsingEncodingNamed:(NSString *)_encoding {
  NSStringEncoding encoding;

  encoding = [NSString stringEncodingForEncodingNamed:_encoding];
  return [self dataUsingEncoding:encoding];
}

@end /* NSString(Encoding) */

#else /* ! NeXT_Foundation_LIBRARY */

@implementation NSString(Encoding)

#ifdef __linux__
static NSString *unicharEncoding = @"UCS-2LE";
#else
static NSString *unicharEncoding = @"UCS-2-INTERNAL";
#endif
static int IconvLogEnabled = -1;

static void checkDefaults(void) {
  NSUserDefaults *ud;
  
  if (IconvLogEnabled != -1) 
    return;
  ud = [NSUserDefaults standardUserDefaults];
  IconvLogEnabled = [ud boolForKey:@"IconvLogEnabled"]?1:0;

#ifdef __linux__
  if (NSHostByteOrder() == NS_BigEndian) {
    NSLog(@"Note: using UCS-2 big endian on Linux.");
    unicharEncoding = @"UCS-2BE";
  }
  else {
    NSLog(@"Note: using UCS-2 little endian on Linux.");
    unicharEncoding = @"UCS-2LE";
  }
#endif
}

static char *iconv_wrapper(id self, char *_src, unsigned _srcLen,
                           NSString *_fromEncode, NSString *_toEncode,
                           unsigned *outLen_)
{
  iconv_t    type;
  size_t     inbytesleft, outbytesleft, write, outlen;
  const char *fromEncode, *toEncode;
  char       *inbuf, *outbuf, *tm;
  NSString   *result;

  checkDefaults();

  if (IconvLogEnabled) {
    [self logWithFormat:@"FromEncode: %@; ToEncode: %@", _fromEncode,
          _toEncode];
  }

  _fromEncode = [_fromEncode uppercaseString];
  _toEncode   = [_toEncode   uppercaseString];

  if (0 && [_fromEncode isEqualToString:_toEncode]) {
    outlen = _srcLen;
    outbuf = calloc(sizeof(char), outlen+1);

    memcpy(outbuf, _src, _srcLen);
    *outLen_ = outlen;
    
    return outbuf;
  }
  result     = nil;
  fromEncode = [_fromEncode cString];
  toEncode   = [_toEncode   cString];
  
  type       = iconv_open(toEncode, fromEncode);
  inbuf      = NULL;
  outbuf     = NULL;
  
  if ((type == (iconv_t)-1)) {
    [self logWithFormat:@"%s: Could not handle iconv encoding. FromEncoding:%@"
          @" to encoding:%@", __PRETTY_FUNCTION__, _fromEncode, _toEncode];
    goto CLEAR_AND_RETURN;
  }
  inbytesleft  = _srcLen;
  inbuf        = _src;
  outlen       = inbytesleft * 3;
  outbuf       = calloc(outlen + 1, sizeof(char));;
  tm           = outbuf;
  outbytesleft = outlen;

  write = iconv(type, &inbuf, &inbytesleft, &tm, &outbytesleft);

  if (write == (size_t)-1) {
    if (errno == EILSEQ) {
      [self logWithFormat:@"Got invalid multibyte sequence. ToEncode: %@"
            @" FromEncode: %@.", _toEncode, _fromEncode];
      if (IconvLogEnabled) {
        [self logWithFormat:@"ByteSequence:\n%s\n", _src];
      }
      goto CLEAR_AND_RETURN;
    }
    else if (errno == EINVAL) {
      [self logWithFormat:@"Got incomplete multibyte sequence. ToEncode: %@"
       @" FromEncode: %@", _toEncode, _fromEncode];
      if (IconvLogEnabled)
        [self logWithFormat:@"ByteSequence:\n%s\n", _src];
      
    }
    else if (errno == E2BIG) {
      [self logWithFormat:
	      @"Got to small outputbuffer (inbytesleft=%d, outbytesleft=%d, "
	      @"outlen=%d). ToEncode: %@ FromEncode: %@", 
	      inbytesleft, outbytesleft, outlen,
	      _toEncode, _fromEncode];
      if (IconvLogEnabled)
        [self logWithFormat:@"ByteSequence:\n%s\n", _src];
      
      goto CLEAR_AND_RETURN;
    }
    else {
      [self logWithFormat:@"Got unexpected error. ToEncode: %@"
       @" FromEncode: %@", _toEncode, _fromEncode];
      goto CLEAR_AND_RETURN;
    }
  }
#if DEBUG_ICONV
  NSLogL(@"outlen %d outbytesleft %d", outlen, outbytesleft);
#endif
  if (type)
    iconv_close(type);
  
  *outLen_ = outlen - outbytesleft;
  
  return outbuf;
  
 CLEAR_AND_RETURN:
  if (type)
    iconv_close(type);
  
  if (outbuf) {
    free(outbuf); outbuf = NULL;
  }
  return NULL;
}

+ (NSString *)stringWithData:(NSData *)_data
  usingEncodingNamed:(NSString *)_encoding
{
  void      *inbuf, *res;
  unsigned  len, inbufLen;
  NSString  *result;

  if (![_encoding length])
    return nil;
  
  inbufLen = [_data length];
  inbuf    = calloc(sizeof(char), inbufLen + 4);
  [_data getBytes:inbuf];
  
  result = nil;
  res    = iconv_wrapper(self, inbuf, inbufLen, _encoding, unicharEncoding, &len);
  if (res) {
    result = [[NSString alloc] initWithCharacters:res length:(len / 2)];
    free(res); res = NULL;
  }
  if (inbuf) free(inbuf); inbuf = NULL;
  return [result autorelease];
}

- (NSData *)dataUsingEncodingNamed:(NSString *)_encoding {
  unichar  *chars;
  char     *res;
  unsigned inputLen, resLen;
  NSData   *data;
  
  if (![_encoding length])
    return nil;

  data     = nil;
  inputLen = [self length];
  chars    = calloc(sizeof(unichar), inputLen + 4);
  [self getCharacters:chars];
  
  res = iconv_wrapper(self, (char *)chars, inputLen*2, 
		      unicharEncoding, _encoding,
                      &resLen);
  if (res) data = [NSData dataWithBytes:res length:resLen];
  
  if (chars) free(chars); chars = NULL;
  return data;
}

@end /* NSString(Encoding) */

#endif /* ! NeXT_Foundation_LIBRARY */
