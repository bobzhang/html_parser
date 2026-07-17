// Transitional: make the derived-trait method promotion explicit so the
// `implicit_impl_as_method` lint stays clean. Delete once the promoted
// methods are no longer relied on (call the trait methods directly).

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend DisallowedTagHandling with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend DisallowedTagHandling with Eq::{equal, not_equal}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend SanitizationPolicy with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend UnsafeHandling with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend UnsafeHandling with Eq::{equal, not_equal}

///|
pub extend UrlFilter with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend UrlHandling with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend UrlHandling with Eq::{equal, not_equal}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend UrlPolicy with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend UrlPolicyRule with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend UrlProxy with Debug::{to_repr}

///|
#deprecated("implicit derived-impl promotion; call the trait method directly")
pub extend UrlRule with Debug::{to_repr}
