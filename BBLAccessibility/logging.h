#import <os/log.h>
#import <asl.h>

#ifndef logging_h


#define logging_h

  // opt1. logging based on unified logging API.
  // requires 10.12 or higher.
  #define   __log(...) os_log_info(OS_LOG_DEFAULT, __VA_ARGS__);

// // opt2.
// // uncomment to do primitive logging.
//  #define   __log(...) NSLog(@__VA_ARGS__);

//  // opt3.
//  // impl the log convension in terms of pre 'os_log' api.
//  #define __log(...) asl_NSLog(NULL, NULL, ASL_LEVEL_INFO, __VA_ARGS__);
//
//  // credit: Peter Hosey.
//  #define asl_NSLog(client, msg, level, format, ...) asl_log(client, msg, level, "%s", [[NSString stringWithFormat:@format, ##__VA_ARGS__] UTF8String])

//  // opt4. silent.
//  #define __log(...) ;

#endif /* logging_h */


