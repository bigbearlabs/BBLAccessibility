//#import <os/log.h>
#import <asl.h>

#ifndef logging_h


#define logging_h

  //#define   __log(...) os_log_info(OS_LOG_DEFAULT, __VA_ARGS__);
  // DISABLED until we can do base builds on 10.12...

// uncomment to do primitive logging.
//  #define   __log(...) NSLog(@__VA_ARGS__);

  // impl the log convension in terms of pre 'os_log' api.
  #define __log(...) asl_NSLog(NULL, NULL, ASL_LEVEL_INFO, __VA_ARGS__);

  // credit: Peter Hosey.
  #define asl_NSLog(client, msg, level, format, ...) asl_log(client, msg, level, "%s", [[NSString stringWithFormat:@format, ##__VA_ARGS__] UTF8String])

#endif /* logging_h */


