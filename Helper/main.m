//
//  main.m
//  Injector
//
//  Created by Erwan Barrier on 8/7/12.
//  Copyright (c) 2012 Erwan Barrier. All rights reserved.
//

#import <launch.h>

#import "Helper.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

dispatch_source_t g_timer_source = NULL;

int main(int argc, char *argv[])
{
  // Init idle-exit timer
  dispatch_queue_t mq = dispatch_get_main_queue();
  g_timer_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, mq);
  assert(g_timer_source != NULL);
  
  /* When the idle-exit timer fires, we just call exit(2) with status 0. */
  dispatch_set_context(g_timer_source, NULL);
  dispatch_source_set_event_handler_f(g_timer_source, (void (*)(void *))exit);
  /* We start off with our timer armed. This is for the simple reason that,
   * upon kicking off the GCD state engine, the first thing we'll get to is
   * a connection on our socket which will disarm the timer. Remember, handling
   * new connections and the firing of the idle-exit timer are synchronized.
   */
  dispatch_time_t t0 = dispatch_time(DISPATCH_TIME_NOW, 5llu * NSEC_PER_SEC);
  dispatch_source_set_timer(g_timer_source, t0, 0llu, 0llu);
  dispatch_resume(g_timer_source);

  
  // Check in mach service
  launch_data_t req = launch_data_new_string(LAUNCH_KEY_CHECKIN);
  assert(req != NULL);

  launch_data_t resp = launch_msg(req);
  assert(resp != NULL);
  assert(launch_data_get_type(resp) == LAUNCH_DATA_DICTIONARY);

  launch_data_t machs = launch_data_dict_lookup(resp, LAUNCH_JOBKEY_MACHSERVICES);
  assert(machs != NULL);
  assert(launch_data_get_type(machs) == LAUNCH_DATA_DICTIONARY);

  launch_data_t machPortData = launch_data_dict_lookup(machs, HELPER_MACH_ID);

  mach_port_t mp = launch_data_get_machport(machPortData);
  launch_data_free(req);
  launch_data_free(resp);

  NSMachPort *rp = [[NSMachPort alloc] initWithMachPort:mp];
  NSConnection *c = [NSConnection connectionWithReceivePort:rp sendPort:nil];

  Helper *injector = [Helper new];
  [c setRootObject:injector];

  [[NSRunLoop currentRunLoop] run];

  return (0);
}
