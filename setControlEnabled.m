function setControlEnabled(control, value)
%SETCONTROLENABLED Safely set a UI control's Enable state (no-op if invalid).
try
    if ~isempty(control) && isvalid(control)
        control.Enable = value;
    end
catch
end
end
