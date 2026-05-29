def _patch_transformers_relative_hf_redirects():
    try:
        import transformers.utils.hub as hf_hub
    except Exception:
        return

    if getattr(hf_hub, "_stylesprint_redirect_patch", False):
        return

    original_head = hf_hub.requests.head

    def head_with_absolute_location(*args, **kwargs):
        response = original_head(*args, **kwargs)
        location = response.headers.get("Location")
        if location and location.startswith("/"):
            endpoint = hf_hub.HUGGINGFACE_CO_RESOLVE_ENDPOINT.rstrip("/")
            response.headers["Location"] = endpoint + location
        return response

    hf_hub.requests.head = head_with_absolute_location
    hf_hub._stylesprint_redirect_patch = True


_patch_transformers_relative_hf_redirects()
