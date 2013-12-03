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
require 'idevice/plist'
require 'idevice/idevice'
require 'idevice/lockdown'


module Idevice
  class ImageMounterError < IdeviceLibError
  end

  # Used to mount developer/debug disk images on the device.
  class ImageMounterClient < C::ManagedOpaquePointer
    include LibHelpers

    def self.release(ptr)
      C.mobile_image_mounter_free(ptr) unless ptr.null?
    end

    def self.attach(opts={})
      _attach_helper("com.apple.mobile.mobile_image_mounter", opts) do |idevice, ldsvc, p_mim|
        err = C.mobile_image_mounter_new(idevice, ldsvc, p_mim)
        raise ImageMounterError, "ImageMounter error: #{err}" if err != :SUCCESS

        mim = p_mim.read_pointer
        raise ImageMounterError, "mobile_image_mounter_new returned a NULL client" if mim.null?
        return new(mim)
      end
    end

    def is_mounted?(image_type="Developer")
      ret = lookup_image(image_type)
      return (ret["ImagePresent"] == true)
    end

    def lookup_image(image_type="Developer")
      FFI::MemoryPointer.new(:pointer) do |p_result|
        err = C.mobile_image_mounter_lookup_image(self, image_type, p_result)
        raise ImageMounterError, "ImageMounter error: #{err}" if err != :SUCCESS

        result = p_result.read_pointer
        raise ImageMounterError, "mobile_image_mounter_lookup_image returned a NULL result" if result.null?

        return Plist_t.new(result).to_ruby
      end
    end

    def mount_image(path, signature, image_type="Developer")
      signature = signature.dup.force_encoding('binary')
      FFI::MemoryPointer.from_bytes(signature) do |p_signature|
        FFI::MemoryPointer.new(:pointer) do |p_result|
          err = C.mobile_image_mounter_mount_image(self, path, p_signature, p_signature.size, image_type, p_result)
          raise ImageMounterError, "ImageMounter error: #{err}" if err != :SUCCESS

          result = p_result.read_pointer
          raise ImageMounterError, "mobile_image_mounter_mount_image returned a NULL result" if result.null?

          return Plist_t.new(result).to_ruby
        end
      end
    end

    def hangup
      err = C.mobile_image_mounter_hangup(self)
      raise ImageMounterError, "ImageMounter error: #{err}" if err != :SUCCESS

      return true
    end
  end

  module C
    ffi_lib 'imobiledevice'

    typedef enum(
      :SUCCESS      ,          0,
      :INVALID_ARG  ,         -1,
      :PLIST_ERROR  ,         -2,
      :CONN_FAILED  ,         -3,
      :UNKNOWN_ERROR,       -256,
    ), :image_mounter_error_t

    #mobile_image_mounter_error_t mobile_image_mounter_new(idevice_t device, lockdownd_service_descriptor_t service, mobile_image_mounter_client_t *client);
    attach_function :mobile_image_mounter_new, [Idevice, LockdownServiceDescriptor, :pointer], :image_mounter_error_t

    #mobile_image_mounter_error_t mobile_image_mounter_free(mobile_image_mounter_client_t client);
    attach_function :mobile_image_mounter_free, [ImageMounterClient], :image_mounter_error_t

    #mobile_image_mounter_error_t mobile_image_mounter_lookup_image(mobile_image_mounter_client_t client, const char *image_type, plist_t *result);
    attach_function :mobile_image_mounter_lookup_image, [ImageMounterClient, :string, :pointer], :image_mounter_error_t

    #mobile_image_mounter_error_t mobile_image_mounter_mount_image(mobile_image_mounter_client_t client, const char *image_path, const char *image_signature, uint16_t signature_length, const char *image_type, plist_t *result);
    attach_function :mobile_image_mounter_mount_image, [ImageMounterClient, :string, :pointer, :uint16, :string, :pointer], :image_mounter_error_t

    #mobile_image_mounter_error_t mobile_image_mounter_hangup(mobile_image_mounter_client_t client);
    attach_function :mobile_image_mounter_hangup, [ImageMounterClient], :image_mounter_error_t

  end
end