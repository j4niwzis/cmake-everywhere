#include <nice/agent.h>

int main(void) {
  NiceAgent *agent = nice_agent_new(NULL, NICE_COMPATIBILITY_RFC5245);
  if (agent == NULL) return 1;
  unsigned stream = nice_agent_add_stream(agent, 1);
  if (stream != 0) nice_agent_remove_stream(agent, stream);
  g_object_unref(agent);
  return stream == 0;
}
