require 'idev/c'
require 'idev/plist'
require 'idev/idevice'
require 'idev/lockdown'

module Idev
  class MisAgentError < Idev::IdeviceLibError
  end

  # Used to manage provisioning profiles on the device.
  class MisAgentClient < C::ManagedOpaquePointer
    include LibHelpers

    def self.release(ptr)
      C.misagent_client_free(ptr) unless ptr.null?
    end

    def self.attach(opts={})
      _attach_helper("com.apple.misagent", opts) do |idevice, ldsvc, p_ma|
        err = C.misagent_client_new(idevice, ldsvc, p_ma)
        raise MisAgentError, "misagent error: #{err}" if err != :SUCCESS

        ma = p_ma.read_pointer
        raise MisAgentError, "misagent_client_new returned a NULL misagent_client_t pointer" if ma.null?
        return new(ma)
      end
    end

    def status_code
      C.misagent_get_status_code(self)
    end

    def profiles
      FFI::MemoryPointer.new(:pointer) do |p_profiles|
        err = C.misagent_copy(self, p_profiles)
        raise MisAgentError, "misagent error: #{err}" if err != :SUCCESS

        profiles = p_profiles.read_pointer
        raise MisAgentError, "misagent_copy returned null profiles plist_t" if profiles.null?
        return Plist_t.new(profiles).to_ruby
      end
    end

    def install(profile_hash)
      err = C.misagent_install(self, profile_hash.to_plist_t)
      raise MisAgentError, "misagent error: #{err}" if err != :SUCCESS

      return status_code
    end

    def remove(profile_ident)
      err = C.misagent_remove(self, profile_ident)
      raise MisAgentError, "misagent error: #{err}" if err != :SUCCESS

      return status_code
    end

  end

  module C
    ffi_lib 'imobiledevice'

    typedef enum(
      :SUCCESS        ,       0,
      :INVALID_ARG    ,      -1,
      :PLIST_ERROR    ,      -2,
      :CONN_FAILED    ,      -3,
      :REQUEST_FAILED ,      -4,
      :UNKNOWN_ERROR  ,    -256,
    ), :misagent_error_t


    #misagent_error_t misagent_client_new(idevice_t device, lockdownd_service_descriptor_t service, misagent_client_t *client);
    attach_function :misagent_client_new, [Idevice, LockdownServiceDescriptor, :pointer], :misagent_error_t

    #misagent_error_t misagent_client_free(misagent_client_t client);
    attach_function :misagent_client_free, [MisAgentClient], :misagent_error_t

    #misagent_error_t misagent_install(misagent_client_t client, plist_t profile);
    attach_function :misagent_install, [MisAgentClient, Plist_t], :misagent_error_t

    #misagent_error_t misagent_copy(misagent_client_t client, plist_t* profiles);
    attach_function :misagent_copy, [MisAgentClient, :pointer], :misagent_error_t

    #misagent_error_t misagent_remove(misagent_client_t client, const char* profileID);
    attach_function :misagent_remove, [MisAgentClient, :string], :misagent_error_t

    #int misagent_get_status_code(misagent_client_t client);
    attach_function :misagent_get_status_code, [MisAgentClient], :int

  end
end
