//===--- KnownProtocols.h - Working with compiler protocols -----*- C++ -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef SWIFT_AST_KNOWNPROTOCOLS_H
#define SWIFT_AST_KNOWNPROTOCOLS_H

#include "swift/Basic/InlineBitfield.h"
#include "swift/Basic/FixedBitSet.h"
#include "swift/Config.h"

namespace llvm {
class StringRef;
}

namespace swift {

/// The set of known protocols.
enum class KnownProtocolKind : uint8_t {
#define PROTOCOL_WITH_NAME(Id, Name) Id,
#include "swift/AST/KnownProtocols.def"
};

enum : uint8_t {
  // This uses a preprocessor trick to count all the protocols. The enum value
  // expression below expands to "+1+1+1...". (Note that the first plus
  // is parsed as a unary operator.)
#define PROTOCOL_WITH_NAME(Id, Name) +1
  /// The number of known protocols.
  NumKnownProtocols =
#include "swift/AST/KnownProtocols.def"
};

enum : unsigned { NumKnownProtocolKindBits =
  countBitsUsed(static_cast<unsigned>(NumKnownProtocols - 1)) };

/// Retrieve the name of the given known protocol.
llvm::StringRef getProtocolName(KnownProtocolKind kind);

/// MARK: Invertible protocols
///
/// The invertible protocols are a subset of the known protocols.

enum : uint8_t {
  // Use preprocessor trick to count all the invertible protocols.
#define INVERTIBLE_PROTOCOL_WITH_NAME(Id, Name) +1
  /// The number of invertible protocols.
  NumInvertibleProtocols =
#include "swift/AST/KnownProtocols.def"
};

enum class InvertibleProtocolKind : uint8_t {
#define INVERTIBLE_PROTOCOL_WITH_NAME(Id, Name) Id,
#include "swift/AST/KnownProtocols.def"
};

using InvertibleProtocolSet = FixedBitSet<NumInvertibleProtocols,
                                          InvertibleProtocolKind>;

/// Maps a KnownProtocol to the set of InvertibleProtocols, if a mapping exists.
/// \returns None if the known protocol is not invertible.
std::optional<InvertibleProtocolKind>
getInvertibleProtocolKind(KnownProtocolKind kp);

/// Returns the KnownProtocolKind corresponding to an InvertibleProtocolKind.
KnownProtocolKind getKnownProtocolKind(InvertibleProtocolKind ip);

void simple_display(llvm::raw_ostream &out,
                    const InvertibleProtocolKind &value);

} // end namespace swift

#endif
