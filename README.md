
# LenvCrypt

WIP: Work In Progress,... __DO NOT USE THIS CODE YET!__ 

![LenvCrypt Logo](./Docs/Images/LenvCrypt_logo.png)

**LenvCrypt**: Linux Environment Encrypted, is a secure, password-protected sandbox storage designed to create an encrypted environment on GNU/Linux systems. LenvCrypt works based on _LUKS_, and aims to provide users with a safe space to run programs and store sensitive data a part of the host system without the risk of exposure.

## How does it work?

LUKS (_Linux Unified Key Setup_) is a standard for Linux disk encryption. LUKS implements a platform-independent standard on-disk format for use in various tools. This facilitates compatibility and interoperability among different programs and operating systems, and assures that they all implement password management in a secure and documented manner.[_from Wikipedia_]

Using LUKS, we can create an encrypted container that we can mount and use as a sandbox.



## Features

- **Encryption**: All data within the LenvCrypt environment is encrypted using strong encryption algorithms to ensure confidentiality. Access to the sandbox is secured with a user-defined password.

- **Open Source**: LenvCrypt is licensed under the GPL3, allowing users to modify and distribute the software freely.

- **Cross-Platform Compatibility**: Designed to work on various GNU/Linux distributions.

## Installation

To install LenvCrypt, follow these steps:

1. **Install dependencies**:
   Make sure you have the _cryptsetup_ installed. You can typically install them using your package manager. For example, on Debian-based systems:
   ```bash
   sudo apt-get install cryptsetup
   ```

2. **Clone the repository and setup**:
   ```bash
   git clone https://github.com/TadavomnisT/LenvCrypt.git
   cd LenvCrypt
   chmod +x lenvcrypt.sh
   ```

3. **Run the application**:
   ```bash
   ./lenvcrypt.sh
   ```

## Usage (_NEEDS A CHANGE_)

To create a new encrypted environment, run the following command:

```bash
./lenvcrypt.sh create
```

You will be prompted to enter a password for the new environment. Once created, you can enter the environment using:

```bash
./lenvcrypt.sh enter
```

To exit the environment, simply type `exit`.

## Contributing

Contributions are welcome! If you would like to contribute to LenvCrypt, please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bug fix.
3. Make your changes and commit them with clear messages.
4. Push your branch to your forked repository.
5. Open a pull request with a description of your changes.

## License

LenvCrypt is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html). See the LICENSE file for more details.

## Contact

For questions, suggestions, or feedback, please open an issue in the repository or contact me at behroora at YAHOO dot COM.

