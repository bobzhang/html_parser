// Transitional: make the derived-trait method promotion explicit so the
// `implicit_impl_as_method` lint stays clean. Delete once the promoted
// methods are no longer relied on (call the trait methods directly).

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend StreamDoctypeEvent with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend StreamDoctypeEvent with Eq::{equal, not_equal}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend StreamEvent with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend StreamEvent with Eq::{equal, not_equal}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend StreamSink with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend StreamStartEvent with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend StreamStartEvent with Eq::{equal, not_equal}
