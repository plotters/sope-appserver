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

#include "GCSFolderManager.h"
#include "GCSChannelManager.h"
#include "GCSFolderType.h"
#include "GCSFolder.h"
#include "NSURL+GCS.h"
#include "EOAdaptorChannel+GCS.h"
#include "common.h"
#include <GDLAccess/EOAdaptorChannel.h>
#include <NGExtensions/NGResourceLocator.h>

/*
  Required database schema:
  
    <arbitary table>
      c_path
      c_path1, path2, path3... [quickPathCount times]
      c_foldername
  
  TODO:
  - add a local cache?
*/

@implementation GCSFolderManager

static GCSFolderManager *fm = nil;
static BOOL       debugOn                   = NO;
static BOOL       debugSQLGen               = NO;
static BOOL       debugPathTraversal        = NO;
static int        quickPathCount            = 4;
static NSArray    *emptyArray               = nil;
#if 0
static NSString   *GCSPathColumnName        = @"c_path";
static NSString   *GCSTypeColumnName        = @"c_folder_type";
static NSString   *GCSTypeRecordName        = @"c_folder_type";
#endif
static NSString   *GCSPathRecordName        = @"c_path";
static NSString   *GCSGenericFolderTypeName = @"Container";
static const char *GCSPathColumnPattern     = "c_path%i";

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn     = [ud boolForKey:@"GCSFolderManagerDebugEnabled"];
  debugSQLGen = [ud boolForKey:@"GCSFolderManagerSQLDebugEnabled"];
  emptyArray  = [[NSArray alloc] init];
}

+ (id)defaultFolderManager {
  NSString *s;
  NSURL    *url;
  if (fm) return fm;
  
  s = [[NSUserDefaults standardUserDefaults] stringForKey:@"OCSFolderInfoURL"];
  if ([s length] == 0) {
    NSLog(@"ERROR(%s): default 'OCSFolderInfoURL' is not configured.",
	  __PRETTY_FUNCTION__);
    return nil;
  }
  if ((url = [NSURL URLWithString:s]) == nil) {
    NSLog(@"ERROR(%s): default 'OCSFolderInfoURL' is not a valid URL: '%@'",
	  __PRETTY_FUNCTION__, s);
    return nil;
  }
  if ((fm = [[self alloc] initWithFolderInfoLocation:url]) == nil) {
    NSLog(@"ERROR(%s): could not create folder manager with URL: '%@'",
	  __PRETTY_FUNCTION__, [url absoluteString]);
    return nil;
  }
  
  NSLog(@"Note: setup default manager at: %@", url);
  return fm;
}

- (NSDictionary *)loadDefaultFolderTypes {
  NSMutableDictionary *typeMap;
  NSArray  *types;
  unsigned i, count;
  
  
  types = [[GCSFolderType resourceLocator] lookupAllFilesWithExtension:@"ocs"
					   doReturnFullPath:NO];
  if ((count = [types count]) == 0) {
    [self logWithFormat:@"Note: no GCS folder types found."];
    return nil;
  }
  
  typeMap = [NSMutableDictionary dictionaryWithCapacity:count];
  
  [self logWithFormat:@"Note: loading %d GCS folder types:", count];
  for (i = 0, count = [types count]; i < count; i++) {
    NSString *type;
    GCSFolderType *typeObject;
    
    type       = [[types objectAtIndex:i] stringByDeletingPathExtension];
    typeObject = [[GCSFolderType alloc] initWithFolderTypeName:type];
    
    [self logWithFormat:@"  %@: %s", 
	    type, [typeObject isNotNull] ? "OK" : "FAIL"];
    [typeMap setObject:typeObject forKey:type];
    [typeObject release];
  }
  
  return typeMap;
}

- (id)initWithFolderInfoLocation:(NSURL *)_url {
  if (_url == nil) {
    [self logWithFormat:@"ERROR(%s): missing folder info url!", 
	    __PRETTY_FUNCTION__];
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    self->channelManager = [[GCSChannelManager defaultChannelManager] retain];
    self->folderInfoLocation = [_url retain];

    if ([[self folderInfoTableName] length] == 0) {
      [self logWithFormat:@"ERROR(%s): missing tablename in URL: %@", 
            __PRETTY_FUNCTION__, [_url absoluteString]];
      [self release];
      return nil;
    }
    
    /* register default folder types */
    self->nameToType = [[self loadDefaultFolderTypes] copy];
  }
  return self;
}

- (void)dealloc {
  [self->nameToType         release];
  [self->folderInfoLocation release];
  [self->channelManager     release];
  [super dealloc];
}

/* accessors */

- (NSURL *)folderInfoLocation {
  return self->folderInfoLocation;
}

- (NSString *)folderInfoTableName {
  return [[self folderInfoLocation] gcsTableName];
}

/* connection */

- (GCSChannelManager *)channelManager {
  return self->channelManager;
}

- (EOAdaptorChannel *)acquireOpenChannel {
  EOAdaptorChannel *ch;
  
  ch = [[self channelManager] acquireOpenChannelForURL:
	      [self folderInfoLocation]];
  return ch;
}
- (void)releaseChannel:(EOAdaptorChannel *)_channel {
  [[self channelManager] releaseChannel:_channel];
  if (debugOn) [self debugWithFormat:@"released channel: %@", _channel];
}

- (BOOL)canConnect {
  return [[self channelManager] canConnect:[self folderInfoLocation]];
}

- (NSArray *)performSQL:(NSString *)_sql {
  EOAdaptorChannel *channel;
  NSException    *ex;
  NSMutableArray *rows;
  NSDictionary   *row;
  NSArray        *attrs;
  
  /* acquire channel */
  
  if ((channel = [self acquireOpenChannel]) == nil) {
    if (debugOn) [self debugWithFormat:@"could not acquire channel!"];
    return nil;
  }
  if (debugOn) [self debugWithFormat:@"acquired channel: %@", channel];
  
  /* run SQL */
  
  if ((ex = [channel evaluateExpressionX:_sql]) != nil) {
    [self logWithFormat:@"ERROR(%s): cannot execute\n  SQL '%@':\n  %@", 
	    __PRETTY_FUNCTION__, _sql, ex];
    [self releaseChannel:channel];
    return nil;
  }
  
  /* fetch results */
  
  attrs = [channel describeResults:NO /* do not beautify names */];
  rows = [NSMutableArray arrayWithCapacity:16];
  while ((row = [channel fetchAttributes:attrs withZone:NULL]) != nil)
    [rows addObject:row];
  
  [self releaseChannel:channel];
  return rows;
}

/* row factory */

- (GCSFolder *)folderForRecord:(NSDictionary *)_record {
  GCSFolder     *folder;
  GCSFolderType *folderType;
  NSString      *folderTypeName, *locationString, *folderName, *path;
  NSNumber      *folderId;
  NSURL         *location, *quickLocation;
  
  if (_record == nil) return nil;
  
  folderTypeName = [_record objectForKey:@"c_folder_type"];
  if (![folderTypeName isNotNull]) {
    [self logWithFormat:@"ERROR(%s): missing type in folder: %@",
	    __PRETTY_FUNCTION__, _record];
    return nil;
  }
  if ((folderType = [self folderTypeWithName:folderTypeName]) == nil) {
    [self logWithFormat:
	    @"ERROR(%s): could not resolve type '%@' of folder: %@",
	    __PRETTY_FUNCTION__,
	    folderTypeName, [_record valueForKey:@"c_path"]];
    return nil;
  }
  
  folderId   = [_record objectForKey:@"c_folder_id"];
  folderName = [_record objectForKey:@"c_path"];
  path       = [self pathFromInternalName:folderName];
  
  locationString = [_record objectForKey:@"c_location"];
  location = [locationString isNotNull] 
    ? [NSURL URLWithString:locationString]
    : nil;
  if (location == nil) {
    [self logWithFormat:@"ERROR(%s): missing folder location in record: %@", 
	    __PRETTY_FUNCTION__, _record];
    return nil;
  }
  
  locationString = [_record objectForKey:@"c_quick_location"];
  quickLocation = [locationString isNotNull] 
    ? [NSURL URLWithString:locationString]
    : nil;

  if (quickLocation == nil) {
    [self logWithFormat:@"WARNING(%s): missing quick location in record: %@", 
	    __PRETTY_FUNCTION__, _record];
  }
  
  folder = [[GCSFolder alloc] initWithPath:path primaryKey:folderId
			      folderTypeName:folderTypeName 
			      folderType:folderType
			      location:location quickLocation:quickLocation
			      folderManager:self];
  return [folder autorelease];
}

/* path SQL */

- (NSString *)generateSQLWhereForInternalNames:(NSArray *)_names
  exactMatch:(BOOL)_beExact orDirectSubfolderMatch:(BOOL)_directSubs
{
  /* generates a WHERE qualifier for matching the "quick" entries */
  NSMutableString *sql;
  unsigned i, count;
  
  if ((count = [_names count]) == 0) {
    [self debugWithFormat:@"WARNING(%s): passed in empty name array!",
	    __PRETTY_FUNCTION__];
    return @"1 = 2";
  }
  
  sql = [NSMutableString stringWithCapacity:(count * 8)];
  for (i = 0; i < quickPathCount; i++) {
    NSString *pathColumn;
    char buf[32];
    
    sprintf(buf, GCSPathColumnPattern, (i + 1));
    pathColumn = [[NSString alloc] initWithCString:buf];
    
    /* Note: the AND addition must be inside the if's for non-exact stuff */
    
    if (i < count) {
      /* exact match, regular column */
      if ([sql length] > 0) [sql appendString:@" AND "];
      [sql appendString:pathColumn];
      [sql appendFormat:@" = '%@'", [_names objectAtIndex:i]];
    }
    else if (_beExact) {
      /* exact match, ensure that all additional quick-cols are NULL */
      if ([sql length] > 0) [sql appendString:@" AND "];
      [sql appendString:pathColumn];
      [sql appendString:@" IS NULL"];
      if (debugPathTraversal) [self logWithFormat:@"BE EXACT, NULL columns"];
    }
    else if (_directSubs) {
      /* fetch immediate subfolders */
      if ([sql length] > 0) [sql appendString:@" AND "];
      [sql appendString:pathColumn];
      if (i == count) {
	/* if it is a direct subfolder, the next path cannot be empty */
	[sql appendString:@" IS NOT NULL"];
	if (debugPathTraversal)
	  [self logWithFormat:@"DIRECT SUBS, first level"];
      }
      else {
	/* but for 'direct' subfolders, all following things must be empty */
	[sql appendString:@" IS NULL"];
	if (debugPathTraversal) 
	  [self logWithFormat:@"DIRECT SUBS, lower level"];
      }
    }
    
    [pathColumn release];
  }
  
  if (_beExact && (count > quickPathCount)) {
    [sql appendString:@" AND c_foldername = '"];
    [sql appendString:[_names lastObject]];
    [sql appendString:@"'"];
  }
  
  return sql;
}

- (NSString *)generateSQLPathFetchForInternalNames:(NSArray *)_names
  exactMatch:(BOOL)_beExact orDirectSubfolderMatch:(BOOL)_directSubs
{
  /* fetches the 'path' subset for a given quick-names */
  NSMutableString *sql;
  NSString *ws;
  
  ws = [self generateSQLWhereForInternalNames:_names 
	     exactMatch:_beExact orDirectSubfolderMatch:_directSubs];
  if ([ws length] == 0)
    return nil;
  
  sql = [NSMutableString stringWithCapacity:256];
  [sql appendString:@"SELECT c_path FROM "];
  [sql appendString:[self folderInfoTableName]];
  [sql appendString:@" WHERE "];
  [sql appendString:ws];
  if (debugSQLGen) [self logWithFormat:@"PathFetch-SQL: %@", sql];
  return sql;
}

/* handling folder names */

- (BOOL)_isStandardizedPath:(NSString *)_path {
  if (![_path isAbsolutePath])                return NO;
  if ([_path rangeOfString:@".."].length > 0) return NO;
  if ([_path rangeOfString:@"~"].length  > 0) return NO;
  if ([_path rangeOfString:@"//"].length > 0) return NO;
  return YES;
}

- (NSString *)internalNameFromPath:(NSString *)_path {
  // TODO: ensure proper path and SQL escaping!
  
  if (![self _isStandardizedPath:_path]) {
    [self debugWithFormat:@"%s: not a standardized path: '%@'", 
	    __PRETTY_FUNCTION__, _path];
    return nil;
  }
  
  if ([_path hasSuffix:@"/"] && [_path length] > 1)
    _path = [_path substringToIndex:([_path length] - 1)];
  
  return _path;
}
- (NSArray *)internalNamesFromPath:(NSString *)_path {
  NSString *fname;
  NSArray  *fnames;
  
  if ((fname = [self internalNameFromPath:_path]) == nil)
    return nil;
  
  if ([fname hasPrefix:@"/"])
    fname = [fname substringFromIndex:1];
  
  fnames = [fname componentsSeparatedByString:@"/"];
  if ([fnames count] == 0)
    return nil;
  
  return fnames;
}
- (NSString *)pathFromInternalName:(NSString *)_name {
  /* for incomplete pathes, like '/Users/helge/' */
  return _name;
}
- (NSString *)pathPartFromInternalName:(NSString *)_name {
  /* for incomplete pathes, like 'Users/' */
  return _name;
}

- (NSDictionary *)filterRecords:(NSArray *)_records forPath:(NSString *)_path {
  unsigned i, count;
  NSString *name;
  
  if (_records == nil) return nil;
  if ((name = [self internalNameFromPath:_path]) == nil) return nil;
  
  for (i = 0, count = [_records count]; i < count; i++) {
    NSDictionary *record;
    NSString     *recName;
    
    record  = [_records objectAtIndex:i];
    recName = [record objectForKey:GCSPathRecordName];
#if 0
    [self logWithFormat:@"check '%@' vs '%@' (%@)...", 
	  name, recName, [_records objectAtIndex:i]];
#endif
    
    if ([name isEqualToString:recName])
      return [_records objectAtIndex:i];
  }
  return nil;
}

- (BOOL)folderExistsAtPath:(NSString *)_path {
  NSString *fname;
  NSArray  *fnames, *records;
  NSString *sql;
  unsigned count;
  
  if ((fnames = [self internalNamesFromPath:_path]) == nil) {
    [self debugWithFormat:@"got no internal names for path: '%@'", _path];
    return NO;
  }
  
  sql = [self generateSQLPathFetchForInternalNames:fnames 
	      exactMatch:YES orDirectSubfolderMatch:NO];
  if ([sql length] == 0) {
    [self debugWithFormat:@"got no SQL for names: %@", fnames];
    return NO;
  }
  
  if ((records = [self performSQL:sql]) == nil) {
    [self logWithFormat:@"ERROR(%s): executing SQL failed: '%@'", 
	    __PRETTY_FUNCTION__, sql];
    return NO;
  }
  
  if ((count = [records count]) == 0)
    return NO;
  
  fname = [self internalNameFromPath:_path];
  if (count == 1) {
    NSDictionary *record;
    NSString *sname;
    
    record = [records objectAtIndex:0];
    sname  = [record objectForKey:GCSPathRecordName];
    return [fname isEqualToString:sname];
  }
  
  [self logWithFormat:@"records: %@", records];
  
  return NO;
}

- (NSArray *)listSubFoldersAtPath:(NSString *)_path recursive:(BOOL)_recursive{
  NSMutableArray *result;
  NSString *fname;
  NSArray  *fnames, *records;
  NSString *sql;
  unsigned i, count;
  
  if ((fnames = [self internalNamesFromPath:_path]) == nil) {
    [self debugWithFormat:@"got no internal names for path: '%@'", _path];
    return nil;
  }
  
  sql = [self generateSQLPathFetchForInternalNames:fnames 
	      exactMatch:NO orDirectSubfolderMatch:(_recursive ? NO : YES)];
  if ([sql length] == 0) {
    [self debugWithFormat:@"got no SQL for names: %@", fnames];
    return nil;
  }
  
  if ((records = [self performSQL:sql]) == nil) {
    [self logWithFormat:@"ERROR(%s): executing SQL failed: '%@'", 
	    __PRETTY_FUNCTION__, sql];
    return nil;
  }
  
  if ((count = [records count]) == 0)
    return emptyArray;

  result = [NSMutableArray arrayWithCapacity:(count > 128 ? 128 : count)];
  
  fname = [self internalNameFromPath:_path];
  fname = [fname stringByAppendingString:@"/"]; /* add slash */
  for (i = 0; i < count; i++) {
    NSDictionary *record;
    NSString *sname, *spath;
    
    record = [records objectAtIndex:i];
    sname  = [record objectForKey:GCSPathRecordName];
    if (![sname hasPrefix:fname]) /* does not match at all ... */
      continue;
    
    /* strip prefix and following slash */
    sname = [sname substringFromIndex:[fname length]];
    spath = [self pathPartFromInternalName:sname];
    
    if (_recursive) {
      if ([spath length] > 0) [result addObject:spath];
    }
    else {
      /* direct children only, so exclude everything with a slash */
      if ([sname rangeOfString:@"/"].length == 0 && [spath length] > 0)
	[result addObject:spath];
    }
  }
  
  return result;
}

- (GCSFolder *)folderAtPath:(NSString *)_path {
  NSMutableString *sql;
  NSArray      *fnames, *records;
  NSString     *ws;
  NSDictionary *record;
  
  if ((fnames = [self internalNamesFromPath:_path]) == nil) {
    [self debugWithFormat:@"got no internal names for path: '%@'", _path];
    return nil;
  }
  
  /* generate SQL to fetch folder attributes */
  
  ws = [self generateSQLWhereForInternalNames:fnames 
	     exactMatch:YES orDirectSubfolderMatch:NO];
  
  sql = [NSMutableString stringWithCapacity:256];
  [sql appendString:@"SELECT "];
  [sql appendString:@"c_folder_id, "];
  [sql appendString:@"c_path, "];
  [sql appendString:@"c_location, c_quick_location, "];
  [sql appendString:@"c_folder_type"];
  [sql appendString:@" FROM "];
  [sql appendString:[self folderInfoTableName]];
  [sql appendString:@" WHERE "];
  [sql appendString:ws];
  
  /* fetching */
  
  if ((records = [self performSQL:sql]) == nil) {
    [self logWithFormat:@"ERROR(%s): executing SQL failed: '%@'", 
	    __PRETTY_FUNCTION__, sql];
    return nil;
  }
  
  // TODO: need to filter on path
  //         required when we start to have deeper hierarchies
  //       => isn't that already done below?
  
  if ([records count] != 1) {
    if ([records count] == 0) {
      [self debugWithFormat:@"found no records for path: '%@'", _path];
      return nil;
    }
    
    [self logWithFormat:@"ERROR(%s): more than one row for path: '%@'", 
	    __PRETTY_FUNCTION__, _path];
    return nil;
  }
  
  if ((record = [self filterRecords:records forPath:_path]) == nil) {
    [self debugWithFormat:@"found no record for path: '%@'", _path];
    return nil;
  }
  
  return [self folderForRecord:record];
}

- (NSException *)createFolderOfType:(NSString *)_type atPath:(NSString *)_path{
  // TODO: implement folder create
  GCSFolderType *ftype;
  
  if ((ftype = [self folderTypeWithName:_type]) == nil) {
    return [NSException exceptionWithName:@"GCSMissingFolderType"
			reason:@"missing folder type"
			userInfo:nil];
  }
  
  [self logWithFormat:@"create folder of type: %@", ftype];
  
  return [NSException exceptionWithName:@"NotYetImplemented"
		      reason:@"no money, no time, ..."
		      userInfo:nil];
}

/* folder types */

- (GCSFolderType *)folderTypeWithName:(NSString *)_name {
  if ([_name length] == 0)
    _name = GCSGenericFolderTypeName;
  
  return [self->nameToType objectForKey:[_name lowercaseString]];
}

/* cache management */

- (void)reset {
  /* does nothing in the moment, but we need a way to signal refreshes */
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  [ms appendFormat:@" url=%@", [self->folderInfoLocation absoluteString]];
  [ms appendFormat:@" channel-manager=0x%p", [self channelManager]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* GCSFolderManager */
