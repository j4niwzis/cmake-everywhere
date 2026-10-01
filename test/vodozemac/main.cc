// A Megolm session made, its key handed to an inbound one, a message
// encrypted by the first and read back by the second -- and an Olm account's
// identity keys, as a device would publish them.
#include <cstdlib>
#include <iostream>
#include <string>

#include <rust/cxx.h>
#include <vodozemac/src/lib.rs.h>

int main() {
  auto outbound = vodozemac::megolm::new_group_session();
  auto inbound = vodozemac::megolm::new_inbound_group_session(*outbound->session_key());
  const std::string said = "hello from cmake-everywhere";
  auto message = outbound->encrypt(said);
  const auto read = inbound->decrypt(*message);
  const std::string back(read.plaintext.begin(), read.plaintext.end());
  if (back != said || read.message_index != 0) {
    std::cerr << "megolm round trip gave \"" << back << "\" at " << read.message_index << "\n";
    return EXIT_FAILURE;
  }
  auto account = vodozemac::olm::new_account();
  const std::string ed25519(account->ed25519_key()->to_base64());
  const std::string curve25519(account->curve25519_key()->to_base64());
  if (ed25519.empty() || curve25519.empty()) {
    std::cerr << "an account with no identity keys\n";
    return EXIT_FAILURE;
  }
  std::cout << "megolm: " << back << "\nolm: ed25519 " << ed25519 << ", curve25519 " << curve25519 << "\n";
  return EXIT_SUCCESS;
}
