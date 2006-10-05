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

#include <NGObjWeb/WODynamicElement.h>

@class NSMutableArray, NSCalendarDate;

#define MatrixSize 42

@interface WEMonthOverview : WODynamicElement
{
  WOAssociation *list;       // list of appointments
  WOAssociation *item;       // current item in list
  WOAssociation *index;      // index of current element
  WOAssociation *identifier; // unique identifier for current item

  WOAssociation *currentDay;  // current day, e.g. 31.Aug, 1.Sep, 2.Sep, ...
  
  WOAssociation *year;        // year
  WOAssociation *month;       // month
  WOAssociation *timeZone;    // timeZone
  
  WOAssociation *firstDay;    // 0 - Sunday .. 6 - Saturday (default:1)
  WOAssociation *tableTags;   // make table tags

  WOAssociation *startDateKey;
  WOAssociation *endDateKey;

  WOAssociation *labelStyle;  // style sheet classes
  WOAssociation *contentStyle;

  WOAssociation *labelColor;
  WOAssociation *contentColor;

@private
  NSMutableArray *matrix[MatrixSize];
  
  struct {
    int firstDisplayedDay; // first day to be displayed Sun 0 .. Sat 6
    int weeks;             // number of weeks to display
    NSCalendarDate *start; // reference date in matrix
  } matrixInfo;
  
  WOElement     *template;
  // extra attributes forwarded to table data
}

@end /* WEMonthOverview */

@interface WEMonthLabel : WODynamicElement
{
  WOAssociation *orientation;
  // left/top | top | right/top | right | right/bottom | bottom | left/bottom
  // left | header
  WOAssociation *dayOfWeek;
  // set if orientation is top or bottom
  WOAssociation *weekOfYear;
  // set if orientation is left or right
  WOAssociation *colspan;
  // set if orientation is header
  WOElement     *template;
}
@end /* WEMonthLabel */

@interface WEMonthTitle : WODynamicElement
{
  WOElement *template;
}
@end /* WEMonthTitle */


#include "WEContextConditional.h"
#include <math.h> /* needed for floor() */
#include "common.h"

static NSString *WEMonthOverview_InfoMode    = @"WEMonthOverview_InfoMode";
static NSString *WEMonthOverview_ContentMode = @"WEMonthOverview_ContentMode";

#define SecondsPerDay (24 * 60 * 60)

@interface WOContext(WEMonthOverview)

- (void)setupMonthOverviewContextWithValue:(id)_value forKey:(NSString *)_key;
- (void)setupMonthOverviewContextForQueryMode;
- (void)setupMonthOverviewContextWithOrientation:(NSString *)_orient;

- (void)tearDownMonthOverviewContext;
- (NSDictionary *)monthOverviewContext;
- (NSMutableArray *)monthOverviewQueryObjects;

- (void)enableMonthOverviewInfoMode;
- (void)disableMonthOverviewInfoMode;
- (void)enableMonthOverviewContentMode;
- (void)disableMonthOverviewContentMode;

@end

@implementation WOContext(WEMonthOverview)

- (void)setupMonthOverviewContextWithValue:(id)_value forKey:(NSString *)_key {
  NSDictionary *d;
  
  d = [[NSDictionary alloc] initWithObjects:&_value forKeys:&_key count:1];
  [self setObject:d forKey:@"WEMonthOverview"];
  [d release];
}
- (void)setupMonthOverviewContextForQueryMode {
  NSDictionary *d;

  d = [[NSDictionary alloc] initWithObjectsAndKeys:
			      [NSMutableArray arrayWithCapacity:4],
			      @"query",nil];
  [self setObject:d forKey:@"WEMonthOverview"];
  [d release];
}
- (void)setupMonthOverviewContextWithOrientation:(NSString *)_orient {
  NSDictionary *d;
  
  d = [[NSDictionary alloc] initWithObjectsAndKeys:@"--", _orient, nil];
  [self setObject:d forKey:@"WEMonthOverview"];
  [d release];
}

- (void)tearDownMonthOverviewContext {
  [self removeObjectForKey:@"WEMonthOverview"];
}

- (NSDictionary *)monthOverviewContext {
  return [self objectForKey:@"WEMonthOverview"];
}
- (NSMutableArray *)monthOverviewQueryObjects {
  return [[self monthOverviewContext] valueForKey:@"query"];
}

- (void)enableMonthOverviewInfoMode {
  [self setObject:@"YES" forKey:WEMonthOverview_InfoMode];
}
- (void)disableMonthOverviewInfoMode {
  [self removeObjectForKey:WEMonthOverview_InfoMode];
}

- (void)enableMonthOverviewContentMode {
  [self setObject:@"YES" forKey:WEMonthOverview_ContentMode];
}
- (void)disableMonthOverviewContentMode {
  [self removeObjectForKey:WEMonthOverview_ContentMode];
}

@end /* WOContext(WEMonthOverview) */

@implementation WEMonthOverview

static Class StrClass = nil;

+ (void)initialize {
  if (StrClass == Nil) StrClass = [NSString class];
}

static NSString *retStrForInt(int i) {
  switch(i) {
  case 0:  return @"0";
  case 1:  return @"1";
  case 2:  return @"2";
  case 3:  return @"3";
  case 4:  return @"4";
  case 5:  return @"5";
  case 6:  return @"6";
  case 7:  return @"7";
  case 8:  return @"8";
  case 9:  return @"9";
  case 10: return @"10";
    // TODO: find useful count!
  default: {
    char buf[32];
    sprintf(buf, "%i", i);
    return [[StrClass alloc] initWithCString:buf];
  }
  }
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary*)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->list         = WOExtGetProperty(_config, @"list");
    self->item         = WOExtGetProperty(_config, @"item");
    self->index        = WOExtGetProperty(_config, @"index");
    self->identifier   = WOExtGetProperty(_config, @"identifier");

    self->currentDay   = WOExtGetProperty(_config, @"currentDay");
    
    self->year         = WOExtGetProperty(_config, @"year");
    self->month        = WOExtGetProperty(_config, @"month");
    self->timeZone     = WOExtGetProperty(_config, @"timeZone");
    self->firstDay     = WOExtGetProperty(_config, @"firstDay");
    self->tableTags    = WOExtGetProperty(_config, @"tableTags");
    
    self->startDateKey = WOExtGetProperty(_config, @"startDateKey");
    self->endDateKey   = WOExtGetProperty(_config, @"endDateKey");

    self->labelStyle   = WOExtGetProperty(_config, @"labelStyle");
    self->contentStyle = WOExtGetProperty(_config, @"contentStyle");

    self->labelColor   = WOExtGetProperty(_config, @"labelColor");
    self->contentColor = WOExtGetProperty(_config, @"contentColor");

    if (self->startDateKey == nil) {
      self->startDateKey = 
        [[WOAssociation associationWithValue:@"startDate"] retain];
    }
    if (self->endDateKey == nil) {
      self->endDateKey = 
        [[WOAssociation associationWithValue:@"endDate"] retain];
    }     
    self->template = [_t retain];
  }
  return self;
}

- (void)resetMatrix {
  int i;
  
  for (i=0; i < MatrixSize; i++) {
    [self->matrix[i] release];
    self->matrix[i] = nil;
  }
  [self->matrixInfo.start release]; self->matrixInfo.start = nil;
}

- (void)dealloc {
  [self->list       release];
  [self->item       release];
  [self->index      release];
  [self->identifier release];
  [self->currentDay release];
  [self->year       release];
  [self->month      release];
  [self->timeZone   release];
  [self->firstDay   release];
  [self->tableTags  release];
  
  [self->startDateKey release];
  [self->endDateKey   release];
  [self->labelStyle   release];
  [self->contentStyle release];
  [self->labelColor   release];
  [self->contentColor release];

  [self resetMatrix];
  
  [self->template release];

  [super dealloc];
}

/* OWResponder */

static inline void
_applyIdentifier(WEMonthOverview *self, WOComponent *comp, NSString *_idx)
{
  NSArray  *array;
  unsigned count;
  unsigned cnt;
  
  array = [self->list valueInComponent:comp];
  count = [array count];

  if (count <= 0)
    return;
    
  /* find subelement for unique id */
    
  for (cnt = 0; cnt < count; cnt++) {
    NSString *ident;
      
    if (self->index)
      [self->index setUnsignedIntValue:cnt inComponent:comp];

    if (self->item)
      [self->item setValue:[array objectAtIndex:cnt] inComponent:comp];
    
    ident = [self->identifier stringValueInComponent:comp];
    
    if ([ident isEqualToString:_idx]) {
      /* found subelement with unique id */
      return;
    }
  }
    
  [comp logWithFormat:
          @"WEMonthOverview: array did change, "
          @"unique-id isn't contained."];
  [self->item  setValue:nil          inComponent:comp];
  [self->index setUnsignedIntValue:0 inComponent:comp];
}

static inline void
_applyIndex(WEMonthOverview *self, WOComponent *comp, unsigned _idx)
{
  NSArray *array;
  unsigned count;

  array = [self->list valueInComponent:comp];
  
  if (self->index)
    [self->index setUnsignedIntValue:_idx inComponent:comp];

  if (self->item == nil)
    return;
  
  count = [array count];
    
  if (_idx < count) {
    [self->item setValue:[array objectAtIndex:_idx] inComponent:comp];
    return;
  }

  [comp logWithFormat:
          @"WEMonthOverview: array did change, index is invalid."];
  [self->item  setValue:nil          inComponent:comp];
  [self->index setUnsignedIntValue:0 inComponent:comp];
}


static inline void
_generateCell(WEMonthOverview *self, WOResponse *response,
              WOContext *ctx, NSString *key, id value,
              NSCalendarDate *dateId)
{
  [ctx setupMonthOverviewContextWithValue:value forKey:key];
  
  [ctx appendElementIDComponent:key];

  if (dateId) {
    NSString *s;
    
    s = retStrForInt([dateId timeIntervalSince1970]);
    [ctx appendElementIDComponent:s];
    [s release];
  }
  
  [self->template appendToResponse:response inContext:ctx];
  
  if (dateId) [ctx deleteLastElementIDComponent];
  [ctx deleteLastElementIDComponent];
  [ctx tearDownMonthOverviewContext];
}

static inline void
_takeValuesInCell(WEMonthOverview *self, WORequest *request,
                  WOContext *ctx, NSString *key, id value)
{
  [ctx setupMonthOverviewContextWithValue:value forKey:key];
  
  [ctx appendElementIDComponent:key];
  [self->template takeValuesFromRequest:request inContext:ctx];
  [ctx deleteLastElementIDComponent];
  // TODO: no teardown of context?
}

- (void)_calcMatrixInContext:(WOContext *)_ctx {
  WOComponent    *comp;
  NSArray        *array;
  NSString       *startKey;
  NSString       *endKey;
  int            m, y; // month, year
  int            i, cnt;

  [self resetMatrix];
  
  comp       = [_ctx component];
  array      = [self->list valueInComponent:comp];
  startKey   = [self->startDateKey stringValueInComponent:comp];
  endKey     = [self->endDateKey   stringValueInComponent:comp];

  y = (self->year == nil)
    ? [[NSCalendarDate calendarDate] yearOfCommonEra]
    : [self->year intValueInComponent:comp];
  
  m = (self->month == nil)
    ? [[NSCalendarDate calendarDate] monthOfYear]
    : [self->month intValueInComponent:comp];
  

  {
    NSCalendarDate *monthStart = nil;
    NSCalendarDate *d  = nil;
    NSTimeZone     *tz = nil;
    int            firstDisplayedDay, firstIdx;
    int            i  = 27;

    tz = [self->timeZone valueInComponent:comp];
    
    monthStart = [NSCalendarDate dateWithYear:y month:m day:1 hour:0 minute:0
                                       second:0 timeZone:tz];
    
    d = [monthStart dateByAddingYears:0 months:0 days:i];

    while ([d monthOfYear] == m) {
      i++;
      d = [monthStart dateByAddingYears:0 months:0 days:i];
    }
    
    firstDisplayedDay = (self->firstDay) 
      ? ([self->firstDay intValueInComponent:comp] % 7)
      : 1; // Monday
    
    firstIdx = (([monthStart dayOfWeek]-firstDisplayedDay)+7) % 7;
    
    self->matrixInfo.weeks = ceil((float)(firstIdx + i) / 7);
    self->matrixInfo.firstDisplayedDay = firstDisplayedDay;

    // keep the timezone in the date
    self->matrixInfo.start =
      [[monthStart dateByAddingYears:0 months:0 days:-firstIdx] retain];
  }
  
  for (i = 0, cnt = [array count]; i < cnt; i++) {
    id             app;
    NSCalendarDate *sd, *ed;
    NSTimeInterval diff;
    int            idx, idx2;

    app = [array objectAtIndex:i];
    sd  = [app valueForKey:startKey]; // startDate
    ed  = [app valueForKey:endKey];   // endDate

    if (sd == nil && ed == nil) continue;

    diff = [sd timeIntervalSinceDate:self->matrixInfo.start];
    
    idx = floor(diff / SecondsPerDay);

    if (0 <= idx  && idx < MatrixSize) {
      if (self->matrix[idx] == nil)
        self->matrix[idx] = [[NSMutableArray alloc] initWithCapacity:4];

      [self->matrix[idx] addObject:[NSNumber numberWithInt:i]];
    }
    idx = (idx < 0) ? 0 : idx + 1;

    diff = [ed timeIntervalSinceDate:self->matrixInfo.start];
    idx2 = floor(diff / SecondsPerDay);
    idx2 = (idx2 > MatrixSize) ? MatrixSize : idx2;
    
    while (idx < idx2) {
      if (self->matrix[idx] == nil)
        self->matrix[idx] = [[NSMutableArray alloc] initWithCapacity:4];

      [self->matrix[idx] addObject:[NSNumber numberWithInt:i]];
      idx++;
    }
  }
  
  for (i = 0; i < MatrixSize; i++) {
    if (self->matrix[i] == nil)
      self->matrix[i] = [[NSArray alloc] init];
  }
}

- (void)appendContentToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  index:(int)_idx
{
  WOComponent  *comp;
  NSArray      *array;
  id           app;
  int          i, cnt, idx, count;

  comp  = [_ctx component];
  array = [self->list valueInComponent:comp];
  count = [array count];

  // *** append day info
  [_ctx enableMonthOverviewInfoMode];
  [_ctx appendElementIDComponent:@"i"];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  [_ctx disableMonthOverviewInfoMode];
  
  // *** append day content
  [_ctx enableMonthOverviewContentMode];
  [_ctx appendElementIDComponent:@"c"]; // append content mode
  for (i = 0, cnt = [self->matrix[_idx] count]; i < cnt; i++) {
    NSString *s;
    
    idx = [[self->matrix[_idx] objectAtIndex:i] intValue];

    if (idx >= count) {
      NSLog(@"Warning! WEMonthOverview: index out of range");
      continue;
    }
    app = [array objectAtIndex:idx];
    
    if ([self->item isValueSettable])
      [self->item  setValue:app inComponent:comp];
    if ([self->index isValueSettable])
      [self->index setIntValue:idx inComponent:comp];

    if (self->identifier == nil) {
      s = retStrForInt(idx);
      [_ctx appendElementIDComponent:s];
      [s release];
    }
    else {
      s = [self->identifier stringValueInComponent:comp];
      [_ctx appendElementIDComponent:s];
    }
    
    [self->template appendToResponse:_response inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  [_ctx deleteLastElementIDComponent]; // delete content mode
  [_ctx disableMonthOverviewContentMode];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent    *comp;
  NSString       *style;
  NSString       *bgcolor;
  BOOL           useTableTags;

  BOOL           renderDefaults = NO;
  BOOL           hasTitle       = NO;
  BOOL           hasHeader      = NO;
  BOOL           hasLeftTop     = NO;
  BOOL           hasLeft        = NO;
  BOOL           hasTop         = NO;
  BOOL           hasRightTop    = NO;
  BOOL           hasRight       = NO;
  BOOL           hasLeftBottom  = NO;
  BOOL           hasBottom      = NO;
  BOOL           hasRightBottom = NO;
  BOOL           hasCell        = NO;

  [self _calcMatrixInContext:_ctx];
      
  comp = [_ctx component];

  useTableTags = (self->tableTags) 
    ? [self->tableTags boolValueInComponent:comp]
    : YES;

  { // query mode ... testing orientations
    NSEnumerator *queryE;
    NSString     *orient;
    
    // only query mode .. no value setting
    [_ctx setupMonthOverviewContextForQueryMode];
    
    /* this walks over all subelements and collects 'query' info */
    
    [self->template appendToResponse:_response inContext:_ctx];
    
    /* now process the results */
    
    queryE = [[_ctx monthOverviewQueryObjects] objectEnumerator];
    
    while ((orient = [queryE nextObject])) {
      if ((!hasHeader) && ([orient isEqualToString:@"header"]))
        hasHeader = YES;
      if ((!hasCell) && ([orient isEqualToString:@"cell"]))
        hasCell = YES;
      if ((!hasTitle) && ([orient isEqualToString:@"title"]))
        hasTitle = YES;
      if ((!hasLeftTop) && ([orient isEqualToString:@"left/top"]))
        hasLeftTop = YES;
      if ((!hasLeftBottom) && ([orient isEqualToString:@"left/bottom"]))
        hasLeftBottom = YES;
      if ((!hasLeft) && ([orient isEqualToString:@"left"]))
        hasLeft = YES;
      if ((!hasTop) && ([orient isEqualToString:@"top"]))
        hasTop = YES;
      if ((!hasRightTop) && ([orient isEqualToString:@"right/top"]))
        hasRightTop = YES;
      if ((!hasRight) && ([orient isEqualToString:@"right"]))
        hasRight = YES;
      if ((!hasRightBottom) && ([orient isEqualToString:@"right/bottom"]))
        hasRightBottom = YES;
      if ((!hasBottom) && ([orient isEqualToString:@"bottom"]))
        hasBottom = YES;
    }

    if (!(hasLeft || hasRight || hasTop || hasBottom))
      renderDefaults = YES;

    [_ctx tearDownMonthOverviewContext];
  }
  
  /* open table */
  if (useTableTags) {
    [_response appendContentString:@"<table"];
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    [_response appendContentString:@">"];
  }

  /* generating head */
  if (hasHeader) {
    NSString *s;
    int width = 7;
    
    if ((hasLeft) || (hasLeftTop) || (hasLeftBottom))
      width++;
    if ((hasRight) || (hasRightTop) || (hasRightBottom))
      width++;

    [_response appendContentString:@"<tr>"];
    
    s = retStrForInt(width);
    _generateCell(self, _response, _ctx, @"header", s, nil);
    [s release];

    [_response appendContentString:@"</tr>"];
  }

  // generating top
  if ((hasTop) || (hasLeftTop) || (hasRightTop) || (renderDefaults)) {
    [_response appendContentString:@"<tr>"];

    if (hasLeftTop)
      _generateCell(self, _response, _ctx, @"left/top", @"--", nil);
    else if (hasLeft || hasLeftBottom || renderDefaults)
      [_response appendContentString:@"<td>&nbsp;</td>"];

    if (hasTop) {
      int i, dow = 0;

      dow = self->matrixInfo.firstDisplayedDay;
      for (i = 0; i < 7; i++) {
        _generateCell(self, _response, _ctx, @"top",
                      [[NSNumber numberWithInt:dow] stringValue], nil);
        dow = (dow == 6) ? 0 : dow+1;
      }
    }
    else if (renderDefaults) {
      NSCalendarDate *day;
      int i;
      
      day = self->matrixInfo.start;
      for (i = 0; i < 7; i++) {
        NSString *s;
        
        [_response appendContentString:@"<td align=\"center\""];
        if ((style = [self->labelStyle stringValueInComponent:comp])) {
            [_response appendContentString:@" class=\""];
            [_response appendContentHTMLAttributeValue:style];
            [_response appendContentCharacter:'"'];
        }
        if ((bgcolor = [self->labelColor stringValueInComponent:comp])) {
          [_response appendContentString:@" bgcolor=\""];
          [_response appendContentString:bgcolor];
          [_response appendContentCharacter:'"'];
        }
        [_response appendContentString:@"><b>"];
        /* TODO: replace with manual string */
        s = [day descriptionWithCalendarFormat:@"%A"];
        [_response appendContentString:s];
        [_response appendContentString:@"</b></td>"];
        day = [day tomorrow];
      }
    }
    else if (hasRightTop || hasLeftTop) {
      [_response appendContentString:
                 @"<td></td><td></td><td></td><td></td>"
                 @"<td></td><td></td><td></td>"];
    }
    
    if (hasRightTop)
      _generateCell(self, _response, _ctx, @"right/top", @"--", nil);
    else if (hasRightBottom || hasRight)
      [_response appendContentString:@"<td>&nbsp;</td>"];

    [_response appendContentString:@"</tr>"];
  }

  /* generating content */
  {
    NSCalendarDate *day;
    NSString       *week;
    int            i, j, maxNumberOfWeeks;

    day = self->matrixInfo.start;
    maxNumberOfWeeks = [day numberOfWeeksInYear];
 
    week = 
      retStrForInt([[day dateByAddingYears:0 months:0 days:3] weekOfYear]);
 
    for (i = 0; i < self->matrixInfo.weeks; i++) {
      [_response appendContentString:@"<tr>"];

      if (hasLeft) {
        _generateCell(self, _response, _ctx, @"left", week, nil);
      }
      else if (renderDefaults) {
        [_response appendContentString:@"<td width=\"2%\" align=\"center\""];
          if ((style = [self->labelStyle stringValueInComponent:comp])) {
              [_response appendContentString:@" class=\""];
              [_response appendContentHTMLAttributeValue:style];
              [_response appendContentCharacter:'"'];
          }
          if ((bgcolor = [self->labelColor stringValueInComponent:comp])) {
          [_response appendContentString:@" bgcolor=\""];
          [_response appendContentString:bgcolor];
          [_response appendContentCharacter:'"'];
        }
        [_response appendContentCharacter:'>'];
        [_response appendContentString:week];
        [_response appendContentString:@"</td>"];
      }
      else if (hasLeftTop || hasLeftBottom)
        [_response appendContentString:@"<td>&nbsp;</td>"];

      /* append days of week */
      for (j = 0; j < 7; j++) {
        NSString *s;
        
        if ([self->currentDay isValueSettable])
          [self->currentDay setValue:day inComponent:comp];
        
        [_response appendContentString:@"<td"];
        if ((style = [self->contentStyle stringValueInComponent:comp])) {
            [_response appendContentString:@" class=\""];
            [_response appendContentHTMLAttributeValue:style];
            [_response appendContentCharacter:'"'];
        }
        if ((bgcolor = [self->contentColor stringValueInComponent:comp])) {
          [_response appendContentString:@" bgcolor=\""];
          [_response appendContentString:bgcolor];
          [_response appendContentCharacter:'"'];
        }
        [_response appendContentCharacter:'>'];

        
        [_response appendContentString:
                   @"<table border='0' height='100%' cellspacing='0'"
                   @" cellpadding='2' width='100%'><tr>"];
        
        if (hasTitle)
          _generateCell(self, _response, _ctx, @"title", @"--", day);
        else {
          [_response appendContentString:
                       @"<td valign=\"top\">"
                       @"<font size=\"4\" color=\"black\">"
                       @"<u>"];
          s = retStrForInt([day dayOfMonth]);
          [_response appendContentString:s];
          [s release];
          [_response appendContentString:@"</u></font></td>"];
        }


        /*** appending content ***/
        [_ctx appendElementIDComponent:@"cell"];
        s = retStrForInt([day timeIntervalSince1970]);
        [_ctx appendElementIDComponent:s];
        [s release];
        [_response appendContentString:@"<td valign=\"top\">"];
        [self appendContentToResponse:_response inContext:_ctx index:(i*7+j)];
        [_response appendContentString:@"</td>"];
        [_ctx deleteLastElementIDComponent]; // delete date
        [_ctx deleteLastElementIDComponent]; // delete "cell"

        [_response appendContentString:@"</tr></table></td>"];
        day  = [day tomorrow];
      }

      if (hasRight)
        _generateCell(self, _response, _ctx, @"right", week, nil);
      else if (hasRightTop || hasRightBottom)
        [_response appendContentString:@"<td>&nbsp;</td>"];
      
      [_response appendContentString:@"</tr>"];
      
      {
         int nextWeek;
         nextWeek = ([week intValue] % maxNumberOfWeeks) + 1;
         [week release]; week = nil;
         week = retStrForInt(nextWeek);
      }
    }
    [week release]; week = nil;
  }
  
  /* generating footer */
  if ((hasBottom) || (hasLeftBottom) || (hasRightBottom)) {

    [_response appendContentString:@"<tr>"];

    if (hasLeftBottom)
      _generateCell(self, _response, _ctx, @"left/bottom", @"--", nil);
    else if (hasLeft || hasLeftTop)
      [_response appendContentString:@"<td>&nbsp;</td>"];

    if (hasBottom) {
      int i, dow = 0; // dayOfWeek

      dow = self->matrixInfo.firstDisplayedDay;
      
      for (i = 0; i < 7; i++) {
        NSString *s;

        s = retStrForInt(dow);
        _generateCell(self, _response, _ctx, @"bottom", s, nil);
        [s release];
        dow = (dow == 6) ? 0 : dow + 1;
      }
    }
    else {
      [_response appendContentString:
                 @"<td></td><td></td><td></td><td></td>"
                 @"<td></td><td></td><td></td>"];
    }

    if (hasRightBottom)
      _generateCell(self, _response, _ctx, @"right/bottom", @"--", nil);
    else if (hasRightTop || hasRight)
      [_response appendContentString:@"<td>&nbsp;</td>"]; 

    [_response appendContentString:@"</tr>"];
  }

  // close table
  if (useTableTags)
    [_response appendContentString:@"</table>"];

  [self resetMatrix];
}


- (void)takeContentValues:(WORequest *)_req inContext:(WOContext *)_ctx
  index:(int)_idx
{
  WOComponent *comp;
  NSString    *s;
  NSArray     *array;
  int         i, cnt, count;

  comp  = [_ctx component];
  array = [self->list valueInComponent:comp];
  count = [array count];
  
  [_ctx appendElementIDComponent:@"c"]; // append content mode
  
  for (i = 0, cnt = [self->matrix[_idx] count]; i < cnt; i++) {
    int idx;
    
    idx = [[self->matrix[_idx] objectAtIndex:i] intValue];

    if (self->index != nil)
      [self->index setUnsignedIntValue:idx inComponent:comp];
    if (self->item != nil)
      [self->item setValue:[array objectAtIndex:idx] inComponent:comp];
    
    s = (self->identifier != nil)
      ? [[self->identifier stringValueInComponent:comp] retain]
      : (id)retStrForInt(idx);
    
    [_ctx appendElementIDComponent:s]; // append index-id
    [s release];
      
    [self->template takeValuesFromRequest:_req inContext:_ctx];
    [_ctx deleteLastElementIDComponent]; // delte index-id
  }
}

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent    *sComponent;
  NSCalendarDate *day;
  NSString       *week;
  int            i, j;
  unsigned int   weekOfYear;
  char           buf[32];
  
  [self _calcMatrixInContext:_ctx];
  
  sComponent = [_ctx component];
  
  day = self->matrixInfo.start;
  
  weekOfYear = [[day dateByAddingYears:0 months:0 days:3] weekOfYear];
  sprintf(buf, "%d", weekOfYear);
  week = [StrClass stringWithCString:buf];
  
  // TODO: weird use of NSString for week?
  for (i = 0; i < self->matrixInfo.weeks; i++) {
    for (j = 0; j < 7; j++) {
      NSString *eid;
      
      if ([self->currentDay isValueSettable])
        [self->currentDay setValue:day inComponent:sComponent];
      
      sprintf(buf, "%d", (unsigned)[day timeIntervalSince1970]);
      eid = [[StrClass alloc] initWithCString:buf];
      [_ctx appendElementIDComponent:eid];
      [eid release];
      
      _takeValuesInCell(self, _req, _ctx, @"title", @"--");
      [self takeContentValues:_req inContext:_ctx index:(i * 7 + j)];
      [_ctx deleteLastElementIDComponent];
      
      day  = [day tomorrow];
    }
    sprintf(buf, "%d", ([week intValue] + 1));
    week = [StrClass stringWithCString:buf];
  }

  [self resetMatrix];
}

- (id)invokeContentAction:(WORequest *)_request inContext:(WOContext *)_ctx{
  id       result = nil;
  NSString *idxId = nil;

  if ((idxId = [_ctx currentElementID]) == 0) // no content nor info mode
    return nil;
    
  [_ctx consumeElementID];                // consume mode
  [_ctx appendElementIDComponent:idxId];  // append mode ("c" or "i")

  if ([idxId isEqualToString:@"i"])
    // info mode
    result = [self->template invokeActionForRequest:_request inContext:_ctx];
  else if ((idxId = [_ctx currentElementID])) {
    // content mode
    [_ctx consumeElementID];               // consume index-id
    [_ctx appendElementIDComponent:idxId];

    if (self->identifier)
      _applyIdentifier(self, [_ctx component], idxId);
    else
      _applyIndex(self, [_ctx component], [idxId intValue]);

    result = [self->template invokeActionForRequest:_request inContext:_ctx];

    [_ctx deleteLastElementIDComponent]; // delete index-id
  }
  [_ctx deleteLastElementIDComponent]; // delete mode
    
  return result;
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent     *sComponent;
  id              result = nil;
  NSString        *ident;
  NSString        *orient;

  sComponent = [_ctx component];
  
  if ((orient = [_ctx currentElementID]) == nil) {
    [[_ctx session]
           logWithFormat:@"%@: MISSING ORIENTATION ID in URL !", self];
    return nil;
  }

  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:orient];
  
  [_ctx setupMonthOverviewContextWithOrientation:orient];
  
  if ([orient isEqualToString:@"cell"] || [orient isEqualToString:@"title"]){
    /* content or 'title' */
    if ((ident = [_ctx currentElementID]) != nil) {
        NSCalendarDate *day;
        int ti;
    
        [_ctx consumeElementID]; // consume date-id
        [_ctx appendElementIDComponent:ident];

        ti = [ident intValue];
      
        day = [NSCalendarDate dateWithTimeIntervalSince1970:ti];
        [day setTimeZone:[self->timeZone valueInComponent:sComponent]];

        if ([self->currentDay isValueSettable])
          [self->currentDay setValue:day inComponent:sComponent];

        if ([orient isEqualToString:@"title"])
          result = [self->template invokeActionForRequest:_req inContext:_ctx];
        else
          result = [self invokeContentAction:_req inContext:_ctx];
        
        [_ctx deleteLastElementIDComponent]; // delete 'cell' or 'title'
    }
    else
      [[_ctx session]
             logWithFormat:@"%@: MISSING DATE ID in '%@' URL !", self, orient];
  }
  else {
    /* neither 'cell' nor 'title' (some label) */
    result = [self->template invokeActionForRequest:_req inContext:_ctx];
  }
  [_ctx deleteLastElementIDComponent]; /* delete orient */

  // TODO: no teardown of month-overview context?
    
  return result;
}

@end /* WEMonthOverview */


@implementation WEMonthLabel

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary*)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->orientation  = WOExtGetProperty(_config, @"orientation");
    self->dayOfWeek    = WOExtGetProperty(_config, @"dayOfWeek");
    self->weekOfYear   = WOExtGetProperty(_config, @"weekOfYear");
    self->colspan      = WOExtGetProperty(_config, @"colspan");

    self->template = [_t retain];
  }
  return self;
}

- (void)dealloc {
  [self->orientation release];
  [self->dayOfWeek   release];
  [self->weekOfYear  release];
  [self->colspan     release];
  
  [self->template release];
  [super dealloc];
}

/* handle requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSDictionary *monthViewContextDict;
  NSString     *orient;
  BOOL         isEdge;
  id tmp;
  
  orient = [self->orientation valueInComponent:[_ctx component]];
  isEdge = ([orient rangeOfString:@"/"].length > 0);
  
  monthViewContextDict  = [_ctx monthOverviewContext];
  if ((tmp = [monthViewContextDict objectForKey:orient]) == nil)
    return;

  if (!isEdge) {
    [_ctx appendElementIDComponent:orient];
    [self->template takeValuesFromRequest:_req inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  else
    [self->template takeValuesFromRequest:_req inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSDictionary *monthViewContextDict;
  NSString     *orient;
  BOOL         isEdge;
  id           result;
  id tmp;
  
  orient = [self->orientation valueInComponent:[_ctx component]];
  isEdge = ([orient rangeOfString:@"/"].length > 0);
  
  monthViewContextDict  = [_ctx monthOverviewContext];
  if ((tmp = [monthViewContextDict objectForKey:orient]) == nil)
    return nil;

  if (isEdge)
    return [self->template invokeActionForRequest:_req inContext:_ctx];

  tmp = [_ctx currentElementID];
  [_ctx consumeElementID];
  [_ctx appendElementIDComponent:tmp];
      
  if ([orient isEqualToString:@"top"] ||
      [orient isEqualToString:@"bottom"]) {
    [self->dayOfWeek setIntValue:[tmp intValue]
                         inComponent:[_ctx component]];
  }
  else if ([orient isEqualToString:@"left"] ||
           [orient isEqualToString:@"right"]) {
    [self->weekOfYear setIntValue:[tmp intValue]
                          inComponent:[_ctx component]];
  }
  else if ([orient isEqualToString:@"header"]) {
    [self->colspan setIntValue:[tmp intValue]
                       inComponent:[_ctx component]];
  }
      
  result = [self->template invokeActionForRequest:_req inContext:_ctx];

  [_ctx deleteLastElementIDComponent];
  return result;
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSDictionary   *monthViewContextDict;
  NSMutableArray *queryContext;
  id       tmp;
  NSString *orient;
  BOOL     isEdge;
  int      cols;

  orient = [self->orientation stringValueInComponent:[_ctx component]];
  isEdge = ([orient rangeOfString:@"/"].length > 0);
  
  if (orient == nil) return;
  
  if ((queryContext = [_ctx monthOverviewQueryObjects]) != nil) {
    [queryContext addObject:orient];
    return;
  }
  
  monthViewContextDict = [_ctx monthOverviewContext];
  if ((tmp = [monthViewContextDict objectForKey:orient]) == nil)
    return;
  
  cols = -1;
  if (!isEdge) {
    int orientIntValue;
    
    orientIntValue = [tmp intValue];
    if ([orient isEqualToString:@"top"] ||
	[orient isEqualToString:@"bottom"]) {
        [self->dayOfWeek setIntValue:orientIntValue 
	                 inComponent:[_ctx component]];
      }
      else if ([orient isEqualToString:@"left"] ||
               [orient isEqualToString:@"right"]) {
        [self->weekOfYear setIntValue:orientIntValue
	                  inComponent:[_ctx component]];
      } 
      else if ([orient isEqualToString:@"header"]) {
        [self->colspan setIntValue:orientIntValue
                       inComponent:[_ctx component]];
        cols = [tmp intValue];
      }
  }
    
  [_response appendContentString:@"<td"];

  if (cols != -1) {
    NSString *colStr;
    
    colStr = retStrForInt(cols);
    [_response appendContentString:@" colspan=\""];
    [_response appendContentString:colStr];
    [_response appendContentString:@"\""];
    [colStr release];
  }
    
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  [_response appendContentString:@">"];
      
  if (!isEdge)
    [_ctx appendElementIDComponent:[tmp stringValue]];
    
  [self->template appendToResponse:_response inContext:_ctx];
    
  if (!isEdge)
    [_ctx deleteLastElementIDComponent];

  // close table data tag
  [_response appendContentString:@"</td>"];
}

@end /* WEMonthLabel */


@implementation WEMonthTitle

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary*)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->template = [_t retain];
  }
  return self;
}

- (void)dealloc {
  [self->template release];
  [super dealloc];
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSDictionary *monthViewContextDict;
  id tmp;
  
  monthViewContextDict  = [_ctx monthOverviewContext];
  if ((tmp = [monthViewContextDict objectForKey:@"title"]) != nil)
    [self->template takeValuesFromRequest:_req inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSDictionary *monthViewContextDict;
  id tmp;
  
  monthViewContextDict  = [_ctx monthOverviewContext];
  if ((tmp = [monthViewContextDict objectForKey:@"title"]) != nil)
    return [self->template invokeActionForRequest:_req inContext:_ctx];
  
  return nil;
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSDictionary *monthViewContextDict;
  id tmp;
  
  if ((tmp = [_ctx monthOverviewQueryObjects]) != nil) {
    [(NSMutableArray *)tmp addObject:@"title"];
    return;
  }
  
  monthViewContextDict = [_ctx monthOverviewContext];
  if ((tmp = [monthViewContextDict objectForKey:@"title"]) != nil) {
    // append table date, forwarding extra attributes
    [_response appendContentString:@"<td"];
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    [_response appendContentString:@">"];
    // append child
    [self->template appendToResponse:_response inContext:_ctx];
    // close table data tag
    [_response appendContentString:@"</td>"];
  }
}

@end /* WEMonthTitle */


@interface WEMonthOverviewInfoMode : WEContextConditional
@end

@implementation WEMonthOverviewInfoMode

- (NSString *)_contextKey {
  return WEMonthOverview_InfoMode;
}

@end /* WEMonthOverviewInfoMode */


@interface WEMonthOverviewContentMode : WEContextConditional
@end

@implementation WEMonthOverviewContentMode

- (NSString *)_contextKey {
  return WEMonthOverview_ContentMode;
}

@end /* WEMonthOverviewContentMode */
