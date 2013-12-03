#
# Copyright (c) 2013 Eric Monti
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'idevice/c'
require 'idevice/idevice'
require 'idevice/lockdown'
require 'idevice/plist'

module Idevice
  class InstProxyError < IdeviceLibError
  end

  class InstProxyClient < C::ManagedOpaquePointer
    include LibHelpers

    def self.release(ptr)
      C.instproxy_client_free(ptr) unless ptr.null?
    end

    def self.attach(opts={})
      _attach_helper("com.apple.mobile.installation_proxy", opts) do |idevice, ldsvc, p_ip|
        err = C.instproxy_client_new(idevice, ldsvc, p_ip)
        raise InstProxyError, "instproxy_client error: #{err}" if err != :SUCCESS

        ip = p_ip.read_pointer
        raise InstProxyError, "instproxy_client_new returned a NULL house_arrest_client_t pointer" if ip.null?

        return new(ip)
      end
    end

    def browse(opts={})
      opts ||= {}
      FFI::MemoryPointer.new(:pointer) do |p_result|
        err = C.instproxy_browse(self, opts.to_plist_t, p_result)
        raise InstProxyError, "instproxy_client error: #{err}" if err != :SUCCESS

        result = p_result.read_pointer
        raise InstProxyError, "instproxy_browse returned a null plist_t" if result.null?

        return Plist_t.new(result).to_ruby
      end
    end

    def install(pkg_path, opts={}, &block)
      opts ||= {}
      err = C.instproxy_install(self, pkg_path, opts.to_plist_t, _cb(&block), nil)
      raise InstProxyError, "instproxy_client error: #{err}" if err != :SUCCESS

      return true
    end

    def upgrade(pkg_path, opts={}, &block)
      opts ||= {}
      err = C.instproxy_upgrade(self, pkg_path, opts.to_plist_t, _cb(&block), nil)
      raise InstProxyError, "instproxy_client error: #{err}" if err != :SUCCESS

      return true
    end

    def uninstall(appid, opts={}, &block)
      opts ||= {}
      err = C.instproxy_uninstall(self, appid, opts.to_plist_t, _cb(&block), nil)
      raise InstProxyError, "instproxy_client error: #{err}" if err != :SUCCESS

      return true
    end

    def lookup_archives(opts={})
      opts ||= {}
      FFI::MemoryPointer.new(:pointer) do |p_result|
        err = C.instproxy_lookup_archives(self, opts.to_plist_t, p_result)
        raise InstProxyError, "instproxy_client error: #{err}" if err != :SUCCESS

        result = p_result.read_pointer
        raise InstProxyError, "instproxy_lookup_archives returned a null plist_t" if result.null?

        return Plist_t.new(result).to_ruby
      end
    end

    def archive(appid, opts={}, &block)
      opts ||= {}
      err = C.instproxy_archive(self, appid, opts.to_plist_t, _cb(&block), nil)
      raise InstProxyError, "instproxy_client error: #{err}" if err != :SUCCESS

      return true
    end

    def restore(appid, opts={}, &block)
      opts ||= {}
      err = C.instproxy_restore(self, appid, opts.to_plist_t, _cb(&block), nil)
      raise InstProxyError, "instproxy_client error: #{err}" if err != :SUCCESS

      return true
    end

    def remove_archive(appid, opts={}, &block)
      opts ||= {}
      err = C.instproxy_remove_archive(self, appid, opts.to_plist_t, _cb(&block), nil)
      raise InstProxyError, "instproxy_client error: #{err}" if err != :SUCCESS

      return true
    end

    private
    def _cb(&blk)
      if blk
        lambda {|op, status, junk| blk.call(op, status.to_ruby) }
      end
    end
  end


  module C
    ffi_lib 'imobiledevice'

    typedef enum(
      :SUCCESS         ,      0,
      :INVALID_ARG     ,     -1,
      :PLIST_ERROR     ,     -2,
      :CONN_FAILED     ,     -3,
      :OP_IN_PROGRESS  ,     -4,
      :OP_FAILED       ,     -5,
      :UNKNOWN_ERROR   ,   -256,
    ), :instproxy_error_t

    #/** Reports the status of the given operation */
    #typedef void (*instproxy_status_cb_t) (const char *operation, plist_t status, void *user_data);
    callback :instproxy_status_cb_t, [:string, Plist_t_Unmanaged, :pointer], :void

    #/* Interface */
    #instproxy_error_t instproxy_client_new(idevice_t device, lockdownd_service_descriptor_t service, instproxy_client_t *client);
    attach_function :instproxy_client_new, [Idevice, LockdownServiceDescriptor, :pointer], :instproxy_error_t

    #instproxy_error_t instproxy_client_free(instproxy_client_t client);
    attach_function :instproxy_client_free, [InstProxyClient], :instproxy_error_t

    #instproxy_error_t instproxy_browse(instproxy_client_t client, plist_t client_options, plist_t *result);
    attach_function :instproxy_browse, [InstProxyClient, Plist_t, :pointer], :instproxy_error_t

    #instproxy_error_t instproxy_install(instproxy_client_t client, const char *pkg_path, plist_t client_options, instproxy_status_cb_t status_cb, void *user_data);
    attach_function :instproxy_install, [InstProxyClient, :string, Plist_t, :instproxy_status_cb_t, :pointer], :instproxy_error_t

    #instproxy_error_t instproxy_upgrade(instproxy_client_t client, const char *pkg_path, plist_t client_options, instproxy_status_cb_t status_cb, void *user_data);
    attach_function :instproxy_upgrade, [InstProxyClient, :string, Plist_t, :instproxy_status_cb_t, :pointer], :instproxy_error_t

    #instproxy_error_t instproxy_uninstall(instproxy_client_t client, const char *appid, plist_t client_options, instproxy_status_cb_t status_cb, void *user_data);
    attach_function :instproxy_uninstall, [InstProxyClient, :string, Plist_t, :instproxy_status_cb_t, :pointer], :instproxy_error_t

    #instproxy_error_t instproxy_lookup_archives(instproxy_client_t client, plist_t client_options, plist_t *result);
    attach_function :instproxy_lookup_archives, [InstProxyClient, Plist_t, :pointer], :instproxy_error_t

    #instproxy_error_t instproxy_archive(instproxy_client_t client, const char *appid, plist_t client_options, instproxy_status_cb_t status_cb, void *user_data);
    attach_function :instproxy_archive, [InstProxyClient, :string, Plist_t, :instproxy_status_cb_t, :pointer], :instproxy_error_t

    #instproxy_error_t instproxy_restore(instproxy_client_t client, const char *appid, plist_t client_options, instproxy_status_cb_t status_cb, void *user_data);
    attach_function :instproxy_restore, [InstProxyClient, :string, Plist_t, :instproxy_status_cb_t, :pointer], :instproxy_error_t

    #instproxy_error_t instproxy_remove_archive(instproxy_client_t client, const char *appid, plist_t client_options, instproxy_status_cb_t status_cb, void *user_data);
    attach_function :instproxy_remove_archive, [InstProxyClient, :string, Plist_t, :instproxy_status_cb_t, :pointer], :instproxy_error_t


    ### favor use of regular plist_t over the less rubyful instproxy_client_options interface

    #plist_t instproxy_client_options_new();
    #attach_function :instproxy_client_options_new, [], Plist_t

    #void instproxy_client_options_add(plist_t client_options, ...);
    #attach_function :instproxy_client_options_add, [Plist_t, :varargs], :void

    #void instproxy_client_options_free(plist_t client_options);
    #attach_function :instproxy_client_options_free, [Plist_t], :void

  end
end